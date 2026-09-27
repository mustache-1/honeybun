// Honeybun API — Cloudflare Worker + D1
// Static files in /public are served automatically; this Worker only handles /api/*.

const SESSION_DAYS = 30;
const COOKIE = "__Host-hb";
const PBKDF2_ITER = 100000; // the most Workers allows
const MAX_MEMBERS = 8;
const RESET_MINUTES = 60;

const CATEGORIES = ["home", "groc", "food", "date", "bills", "car", "fun", "pets", "other"];
const EMOJIS = ["🐰", "🐻", "🐱", "🐶", "🦊", "🐼", "🐨", "🐸", "🐧", "🦄", "🐥", "🐹"];
const COLORS = ["#FFD6E5", "#FFF0C2", "#DDF5E9", "#E4EDFF", "#EADFFF", "#FFE1CC"];
const ACCENTS = ["blueberry", "blush", "lavender", "honey"];
const FREQS = ["weekly", "biweekly", "monthly"];
const SPLITS = ["equal", "percent", "owed"];

// ---------- database setup (runs automatically, once per Worker instance) ----------
const TABLES = [
  `CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, name TEXT NOT NULL, pw TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id)`,
  `CREATE TABLE IF NOT EXISTS nests (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '', invite_code TEXT NOT NULL UNIQUE, accent TEXT NOT NULL DEFAULT 'blueberry', goal_name TEXT NOT NULL DEFAULT 'Weekend getaway', goal_target INTEGER NOT NULL DEFAULT 80000, goal_saved INTEGER NOT NULL DEFAULT 0, created_by TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS members (nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, emoji TEXT NOT NULL, color TEXT NOT NULL, joined_at INTEGER NOT NULL, PRIMARY KEY (nest_id, user_id))`,
  `CREATE TABLE IF NOT EXISTS entries (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, member_id TEXT NOT NULL, type TEXT NOT NULL CHECK (type IN ('income','expense')), amount_cents INTEGER NOT NULL CHECK (amount_cents > 0), label TEXT NOT NULL, category TEXT, shared INTEGER NOT NULL DEFAULT 0, date TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL, split_mode TEXT, split_value INTEGER, shares TEXT, private INTEGER NOT NULL DEFAULT 0, recurring_id TEXT, occ_date TEXT)`,
  `CREATE INDEX IF NOT EXISTS idx_entries_nest_date ON entries(nest_id, date)`,
  `CREATE TABLE IF NOT EXISTS auth_attempts (key TEXT NOT NULL, ts INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_attempts ON auth_attempts(key, ts)`,
  `CREATE TABLE IF NOT EXISTS password_resets (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS settlements (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, from_id TEXT NOT NULL, to_id TEXT NOT NULL, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0), date TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_settlements_nest ON settlements(nest_id)`,
  `CREATE TABLE IF NOT EXISTS jar_moves (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, member_id TEXT NOT NULL, amount_cents INTEGER NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_jar_nest ON jar_moves(nest_id)`,
  `CREATE TABLE IF NOT EXISTS recurring (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, type TEXT NOT NULL CHECK (type IN ('income','expense')), label TEXT NOT NULL, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0), category TEXT, member_id TEXT NOT NULL, shared INTEGER NOT NULL DEFAULT 0, split_mode TEXT, split_value INTEGER, freq TEXT NOT NULL, anchor_date TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_recurring_nest ON recurring(nest_id)`,
];
const ENTRY_COLUMNS = [["split_mode", "TEXT"], ["split_value", "INTEGER"], ["shares", "TEXT"], ["private", "INTEGER NOT NULL DEFAULT 0"], ["recurring_id", "TEXT"], ["occ_date", "TEXT"]];

let schemaReady = null;
function ensureSchema(env) {
  if (!schemaReady) schemaReady = migrate(env).catch((e) => { schemaReady = null; throw e; });
  return schemaReady;
}
async function migrate(env) {
  await env.DB.batch(TABLES.map((s) => env.DB.prepare(s)));
  const cols = (await env.DB.prepare("PRAGMA table_info(entries)").all()).results.map((c) => c.name);
  for (const [name, type] of ENTRY_COLUMNS) {
    if (cols.includes(name)) continue;
    try { await env.DB.prepare(`ALTER TABLE entries ADD COLUMN ${name} ${type}`).run(); }
    catch (e) { if (!String(e.message).includes("duplicate column")) throw e; }
  }
  await env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_entries_occ ON entries(recurring_id, occ_date)").run();
}

// ---------- responses ----------
const SEC_HEADERS = {
  "x-content-type-options": "nosniff",
  "referrer-policy": "strict-origin-when-cross-origin",
  "x-frame-options": "DENY",
  "cache-control": "no-store",
};
const json = (data, status = 200, extra = {}) =>
  new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json; charset=utf-8", ...SEC_HEADERS, ...extra } });
const fail = (message, status = 400) => json({ error: message }, status);
class HttpError extends Error { constructor(message, status = 400) { super(message); this.status = status; } }

const now = () => Math.floor(Date.now() / 1000);
const enc = new TextEncoder();

// ---------- crypto ----------
const b64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const fromB64u = (s) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));
const randomToken = () => b64u(crypto.getRandomValues(new Uint8Array(32)));

async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey("raw", enc.encode(password), "PBKDF2", false, ["deriveBits"]);
  return new Uint8Array(await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256));
}
async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  return `pbkdf2$${PBKDF2_ITER}$${b64u(salt)}$${b64u(await pbkdf2(password, salt, PBKDF2_ITER))}`;
}
async function verifyPassword(password, stored) {
  const [alg, iter, salt, hash] = stored.split("$");
  if (alg !== "pbkdf2") return false;
  const got = await pbkdf2(password, fromB64u(salt), Number(iter));
  const want = fromB64u(hash);
  if (got.length !== want.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got[i] ^ want[i];
  return diff === 0;
}
const DUMMY_HASH = "pbkdf2$100000$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
const sha256 = async (text) => b64u(await crypto.subtle.digest("SHA-256", enc.encode(text)));

function inviteCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from(crypto.getRandomValues(new Uint8Array(8)), (b) => alphabet[b % 32]).join("");
}

// ---------- sessions ----------
function readCookie(request, name) {
  for (const part of (request.headers.get("cookie") || "").split(/;\s*/)) {
    const i = part.indexOf("=");
    if (i > 0 && part.slice(0, i) === name) return part.slice(i + 1);
  }
  return null;
}
async function createSession(env, userId) {
  const token = randomToken(), maxAge = SESSION_DAYS * 86400;
  await env.DB.prepare("INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)").bind(await sha256(token), userId, now() + maxAge).run();
  return `${COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;
}
const clearCookie = `${COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;
async function currentUser(request, env) {
  const token = readCookie(request, COOKIE);
  if (!token) return null;
  const hash = await sha256(token);
  const user = await env.DB.prepare(
    "SELECT u.id, u.email, u.name FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > ?"
  ).bind(hash, now()).first();
  if (user) user.session = hash;
  return user;
}

// ---------- rate limiting ----------
async function limited(env, key, max, windowSec) {
  const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM auth_attempts WHERE key = ? AND ts > ?").bind(key, now() - windowSec).first();
  return row.n >= max;
}
const recordAttempt = (env, key) => env.DB.prepare("INSERT INTO auth_attempts (key, ts) VALUES (?, ?)").bind(key, now()).run();

// ---------- email (Resend) ----------
async function sendEmail(env, to, subject, text, html) {
  if (!env.RESEND_API_KEY) throw new HttpError("Password reset emails aren't set up yet. Ask the site owner to add the email key.", 503);
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({ from: env.MAIL_FROM || "Honeybun <hello@honeybun.me>", to: [to], subject, text, html }),
  });
  if (!res.ok) { console.error("Resend error", res.status, await res.text()); throw new HttpError("Couldn't send the email. Try again in a minute.", 502); }
}

// ---------- validation ----------
const cleanText = (v, max) => String(v ?? "").replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, max);
const isEmail = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) && e.length <= 254;
const isDate = (d) => typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d) && !Number.isNaN(Date.parse(d));
const checkPassword = (p) => { if (typeof p !== "string" || p.length < 8 || p.length > 200) throw new HttpError("Use a password with at least 8 characters."); return p; };
function toCents(v, what = "an amount") {
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0 || n > 10_000_000) throw new HttpError(`Enter ${what} between $0.01 and $10,000,000.`);
  return Math.round(n * 100);
}
const todayStr = () => new Date().toISOString().slice(0, 10);

async function membership(env, userId) {
  return env.DB.prepare("SELECT nest_id FROM members WHERE user_id = ?").bind(userId).first();
}
async function requireNest(env, user) {
  const m = await membership(env, user.id);
  if (!m) throw new HttpError("You're not in a budget yet.", 404);
  return m.nest_id;
}
async function memberIds(env, nestId) {
  return (await env.DB.prepare("SELECT user_id FROM members WHERE nest_id = ? ORDER BY joined_at").bind(nestId).all()).results.map((r) => r.user_id);
}

// Splits: who is responsible for how much of a shared expense (in cents).
//  equal   – everyone pays the same
//  percent – split_value = % the payer covers; the rest is split evenly between the others
//  owed    – split_value = cents the others owe in total, split evenly between them
function computeShares(amount, mode, value, payer, ids) {
  const others = ids.filter((id) => id !== payer);
  if (!others.length) return { [payer]: amount };
  let payerShare;
  if (mode === "percent") payerShare = Math.round((amount * Math.min(100, Math.max(0, value))) / 100);
  else if (mode === "owed") payerShare = amount - Math.min(amount, Math.max(0, value));
  else payerShare = amount - Math.floor(amount / ids.length) * others.length;
  const rest = amount - payerShare, each = Math.floor(rest / others.length);
  const shares = { [payer]: payerShare };
  others.forEach((id, i) => (shares[id] = each + (i < rest - each * others.length ? 1 : 0)));
  return shares;
}
function readSplit(body, amount) {
  const mode = SPLITS.includes(body.split_mode) ? body.split_mode : "equal";
  let value = null;
  if (mode === "percent") {
    value = Math.round(Number(body.split_value));
    if (!Number.isFinite(value) || value < 0 || value > 100) throw new HttpError("Enter a percent from 0 to 100.");
  } else if (mode === "owed") {
    value = Math.round(Number(body.split_value) * 100);
    if (!Number.isFinite(value) || value <= 0 || value > amount) throw new HttpError("The amount owed has to be more than $0 and no more than the total.");
  }
  return { mode, value };
}

// Build a clean entry from the request body (used for create + edit)
async function readEntry(env, nestId, user, body) {
  const type = body.type === "income" ? "income" : body.type === "expense" ? "expense" : null;
  if (!type) throw new HttpError("Bad entry type.");
  const amount = toCents(body.amount);
  const ids = await memberIds(env, nestId);
  const memberId = String(body.member_id ?? "");
  if (!ids.includes(memberId)) throw new HttpError("Pick who paid.");
  const shared = type === "expense" && !!body.shared && ids.length > 1;
  let split = { mode: null, value: null }, shares = null;
  if (shared) { split = readSplit(body, amount); shares = JSON.stringify(computeShares(amount, split.mode, split.value, memberId, ids)); }
  const priv = !shared && !!body.private && memberId === user.id ? 1 : 0;
  return {
    type, amount, memberId, shared: shared ? 1 : 0, split, shares, priv,
    category: type === "expense" ? (CATEGORIES.includes(body.category) ? body.category : "other") : null,
    label: cleanText(body.label, 40) || (type === "income" ? "Paycheck" : "Expense"),
    date: isDate(body.date) ? body.date : todayStr(),
  };
}
async function insertEntry(env, nestId, user, e, recurringId = null, occDate = null) {
  const id = crypto.randomUUID();
  await env.DB.prepare(
    `INSERT INTO entries (id, nest_id, member_id, type, amount_cents, label, category, shared, split_mode, split_value, shares, private, date, recurring_id, occ_date, created_by, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(id, nestId, e.memberId, e.type, e.amount, e.label, e.category, e.shared, e.split.mode, e.split.value, e.shares, e.priv, e.date, recurringId, occDate, user.id, now()).run();
  return id;
}

// ---------- routes ----------
async function handle(request, env, url) {
  const path = url.pathname, method = request.method;
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const appUrl = (env.APP_URL || url.origin).replace(/\/$/, "");

  let body = {};
  if (method === "POST" || method === "PATCH") {
    body = await request.json().catch(() => null);
    if (!body || typeof body !== "object") throw new HttpError("Invalid request.");
  }

  // ===== public =====
  if (path === "/api/signup" && method === "POST") {
    if (await limited(env, "signup:" + ip, 10, 3600)) throw new HttpError("Too many sign-ups from here. Try again in an hour.", 429);
    const name = cleanText(body.name, 24), email = cleanText(body.email, 254).toLowerCase();
    if (!name) throw new HttpError("Enter your name.");
    if (!isEmail(email)) throw new HttpError("Enter a valid email address.");
    const password = checkPassword(body.password);
    await recordAttempt(env, "signup:" + ip);
    if (await env.DB.prepare("SELECT 1 FROM users WHERE email = ?").bind(email).first())
      throw new HttpError("An account with that email already exists. Log in instead.", 409);
    const id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO users (id, email, name, pw, created_at) VALUES (?, ?, ?, ?, ?)").bind(id, email, name, await hashPassword(password), now()).run();
    return json({ ok: true }, 201, { "set-cookie": await createSession(env, id) });
  }

  if (path === "/api/login" && method === "POST") {
    const email = cleanText(body.email, 254).toLowerCase(), password = String(body.password ?? "");
    if ((await limited(env, "login:" + email, 10, 900)) || (await limited(env, "loginip:" + ip, 40, 900)))
      throw new HttpError("Too many tries. Wait 15 minutes and try again.", 429);
    const user = await env.DB.prepare("SELECT id, pw FROM users WHERE email = ?").bind(email).first();
    const ok = await verifyPassword(password, user ? user.pw : DUMMY_HASH);
    if (!user || !ok) {
      await recordAttempt(env, "login:" + email); await recordAttempt(env, "loginip:" + ip);
      throw new HttpError("Wrong email or password.", 401);
    }
    return json({ ok: true }, 200, { "set-cookie": await createSession(env, user.id) });
  }

  if (path === "/api/logout" && method === "POST") {
    const token = readCookie(request, COOKIE);
    if (token) await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(await sha256(token)).run();
    return json({ ok: true }, 200, { "set-cookie": clearCookie });
  }

  if (path === "/api/password/forgot" && method === "POST") {
    const email = cleanText(body.email, 254).toLowerCase();
    if (!isEmail(email)) throw new HttpError("Enter a valid email address.");
    if ((await limited(env, "forgot:" + email, 3, 3600)) || (await limited(env, "forgotip:" + ip, 10, 3600)))
      throw new HttpError("Too many reset requests. Try again in an hour.", 429);
    await recordAttempt(env, "forgot:" + email); await recordAttempt(env, "forgotip:" + ip);
    const user = await env.DB.prepare("SELECT id, name FROM users WHERE email = ?").bind(email).first();
    if (user) {
      const token = randomToken();
      await env.DB.batch([
        env.DB.prepare("DELETE FROM password_resets WHERE user_id = ?").bind(user.id),
        env.DB.prepare("INSERT INTO password_resets (token_hash, user_id, expires_at) VALUES (?, ?, ?)").bind(await sha256(token), user.id, now() + RESET_MINUTES * 60),
      ]);
      const link = `${appUrl}/reset/${token}`;
      await sendEmail(env, email, "Reset your Honeybun password",
        `Hi ${user.name},\n\nTap this link to choose a new Honeybun password:\n${link}\n\nIt works for ${RESET_MINUTES} minutes. If you didn't ask for this, you can ignore this email.`,
        `<div style="font-family:system-ui,sans-serif;max-width:420px;margin:auto;color:#2B2733">
          <p>Hi ${user.name.replace(/[<>&"]/g, "")},</p>
          <p>Tap the button to choose a new Honeybun password.</p>
          <p><a href="${link}" style="display:inline-block;background:#6F93DB;color:#fff;padding:12px 20px;border-radius:12px;text-decoration:none;font-weight:700">Choose a new password</a></p>
          <p style="color:#8E8898;font-size:14px">This link works for ${RESET_MINUTES} minutes. If you didn't ask for this, you can ignore this email.</p>
        </div>`);
    }
    // same answer either way, so nobody can use this to check who has an account
    return json({ ok: true });
  }

  if (path === "/api/password/reset" && method === "POST") {
    const token = String(body.token ?? "");
    const password = checkPassword(body.password);
    if (await limited(env, "resetip:" + ip, 20, 3600)) throw new HttpError("Too many tries. Try again later.", 429);
    await recordAttempt(env, "resetip:" + ip);
    const hash = await sha256(token);
    const row = await env.DB.prepare("SELECT user_id FROM password_resets WHERE token_hash = ? AND expires_at > ?").bind(hash, now()).first();
    if (!row) throw new HttpError("This reset link has expired or was already used. Ask for a new one.", 400);
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET pw = ? WHERE id = ?").bind(await hashPassword(password), row.user_id),
      env.DB.prepare("DELETE FROM password_resets WHERE user_id = ?").bind(row.user_id),
      env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(row.user_id), // log out everywhere
    ]);
    return json({ ok: true }, 200, { "set-cookie": await createSession(env, row.user_id) });
  }

  // ===== signed in =====
  const user = await currentUser(request, env);
  if (!user) throw new HttpError("Please log in.", 401);
  const me = { id: user.id, email: user.email, name: user.name };

  if (path === "/api/me" && method === "GET") {
    const m = await membership(env, user.id);
    return json({ user: me, nest_id: m ? m.nest_id : null });
  }

  if (path === "/api/password/change" && method === "POST") {
    const row = await env.DB.prepare("SELECT pw FROM users WHERE id = ?").bind(user.id).first();
    if (await limited(env, "change:" + user.id, 10, 900)) throw new HttpError("Too many tries. Wait 15 minutes.", 429);
    if (!(await verifyPassword(String(body.current ?? ""), row.pw))) { await recordAttempt(env, "change:" + user.id); throw new HttpError("Your current password is wrong."); }
    const password = checkPassword(body.password);
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET pw = ? WHERE id = ?").bind(await hashPassword(password), user.id),
      env.DB.prepare("DELETE FROM sessions WHERE user_id = ? AND token_hash != ?").bind(user.id, user.session), // log out other devices
    ]);
    return json({ ok: true });
  }

  if (path === "/api/me" && method === "PATCH") {
    const nestId = await requireNest(env, user);
    if (body.name !== undefined) {
      const name = cleanText(body.name, 24);
      if (!name) throw new HttpError("Enter a name.");
      await env.DB.prepare("UPDATE users SET name = ? WHERE id = ?").bind(name, user.id).run();
    }
    if (body.emoji !== undefined) {
      if (!EMOJIS.includes(body.emoji)) throw new HttpError("Pick one of the buddies.");
      await env.DB.prepare("UPDATE members SET emoji = ? WHERE user_id = ? AND nest_id = ?").bind(body.emoji, user.id, nestId).run();
    }
    if (body.color !== undefined) {
      if (!COLORS.includes(body.color)) throw new HttpError("Pick one of the colors.");
      await env.DB.prepare("UPDATE members SET color = ? WHERE user_id = ? AND nest_id = ?").bind(body.color, user.id, nestId).run();
    }
    return json({ ok: true });
  }

  if (path === "/api/nests" && method === "POST") {
    if (await membership(env, user.id)) throw new HttpError("You're already in a budget.", 409);
    const id = crypto.randomUUID();
    await env.DB.batch([
      env.DB.prepare("INSERT INTO nests (id, name, invite_code, created_by, created_at) VALUES (?, ?, ?, ?, ?)").bind(id, cleanText(body.name, 24), inviteCode(), user.id, now()),
      env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at) VALUES (?, ?, ?, ?, ?)").bind(id, user.id, EMOJIS[0], COLORS[0], now()),
    ]);
    return json({ ok: true, nest_id: id }, 201);
  }

  if (path === "/api/nests/join" && method === "POST") {
    if (await limited(env, "join:" + user.id, 20, 3600)) throw new HttpError("Too many tries. Try again later.", 429);
    await recordAttempt(env, "join:" + user.id);
    const code = String(body.code ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    const nest = await env.DB.prepare("SELECT id FROM nests WHERE invite_code = ?").bind(code).first();
    if (!nest) throw new HttpError("That invite code doesn't match any budget. Check it and try again.", 404);
    const mine = await membership(env, user.id);
    if (mine) {
      if (mine.nest_id === nest.id) return json({ ok: true, nest_id: nest.id });
      throw new HttpError("You're already in a budget. Leave it in Settings first, then join this one.", 409);
    }
    const members = (await env.DB.prepare("SELECT emoji, color FROM members WHERE nest_id = ?").bind(nest.id).all()).results;
    if (members.length >= MAX_MEMBERS) throw new HttpError("This budget is full.", 409);
    const emoji = EMOJIS.find((e) => !members.some((m) => m.emoji === e)) || EMOJIS[0];
    const color = COLORS.find((c) => !members.some((m) => m.color === c)) || COLORS[0];
    await env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at) VALUES (?, ?, ?, ?, ?)").bind(nest.id, user.id, emoji, color, now()).run();
    return json({ ok: true, nest_id: nest.id });
  }

  // ----- everything below is inside a budget -----
  const nestId = await requireNest(env, user);

  if (path === "/api/nest" && method === "GET") {
    const month = url.searchParams.get("month") || "";
    if (!/^\d{4}-\d{2}$/.test(month)) throw new HttpError("Bad month.");
    const since = new Date(Date.now() - 45 * 86400000).toISOString().slice(0, 10);
    const [nest, members, entries, sharedAll, settlements, recurring, logged, jar] = await env.DB.batch([
      env.DB.prepare("SELECT id, name, invite_code, accent, goal_name, goal_target, goal_saved FROM nests WHERE id = ?").bind(nestId),
      env.DB.prepare("SELECT u.id, u.name, m.emoji, m.color FROM members m JOIN users u ON u.id = m.user_id WHERE m.nest_id = ? ORDER BY m.joined_at").bind(nestId),
      env.DB.prepare(
        `SELECT id, member_id, type, amount_cents, label, category, shared, split_mode, split_value, shares, private, date, recurring_id, occ_date, created_at
         FROM entries WHERE nest_id = ? AND date >= ? AND date <= ? AND (private = 0 OR member_id = ?) ORDER BY date DESC, created_at DESC`
      ).bind(nestId, month + "-01", month + "-31", user.id),
      env.DB.prepare("SELECT member_id, amount_cents, shares FROM entries WHERE nest_id = ? AND type = 'expense' AND shared = 1").bind(nestId),
      env.DB.prepare("SELECT id, from_id, to_id, amount_cents, date, created_at FROM settlements WHERE nest_id = ? ORDER BY date DESC, created_at DESC").bind(nestId),
      env.DB.prepare("SELECT id, type, label, amount_cents, category, member_id, shared, split_mode, split_value, freq, anchor_date FROM recurring WHERE nest_id = ? ORDER BY type DESC, label").bind(nestId),
      env.DB.prepare("SELECT recurring_id, occ_date FROM entries WHERE nest_id = ? AND recurring_id IS NOT NULL AND occ_date >= ?").bind(nestId, since),
      env.DB.prepare("SELECT id, member_id, amount_cents, created_at FROM jar_moves WHERE nest_id = ? ORDER BY created_at DESC LIMIT 12").bind(nestId),
    ]);

    // running "who owes whom" balance across all time (positive = others owe you)
    const ids = members.results.map((m) => m.id);
    const balances = Object.fromEntries(ids.map((id) => [id, 0]));
    for (const e of sharedAll.results) {
      let shares; try { shares = JSON.parse(e.shares); } catch { shares = null; }
      if (!shares) shares = computeShares(e.amount_cents, "equal", null, e.member_id, ids.includes(e.member_id) ? ids : [e.member_id, ...ids]);
      if (e.member_id in balances) balances[e.member_id] += e.amount_cents;
      for (const [id, c] of Object.entries(shares)) if (id in balances) balances[id] -= c;
    }
    for (const s of settlements.results) {
      if (s.from_id in balances) balances[s.from_id] += s.amount_cents;
      if (s.to_id in balances) balances[s.to_id] -= s.amount_cents;
    }

    return json({
      me, nest: nest.results[0], members: members.results, entries: entries.results,
      balances, settlements: settlements.results.slice(0, 10), recurring: recurring.results,
      logged: logged.results, jar: jar.results,
    });
  }

  if (path === "/api/nest" && method === "PATCH") {
    if (body.name !== undefined) await env.DB.prepare("UPDATE nests SET name = ? WHERE id = ?").bind(cleanText(body.name, 24), nestId).run();
    if (body.accent !== undefined) {
      if (!ACCENTS.includes(body.accent)) throw new HttpError("Unknown theme.");
      await env.DB.prepare("UPDATE nests SET accent = ? WHERE id = ?").bind(body.accent, nestId).run();
    }
    if (body.goal_name !== undefined || body.goal_target !== undefined) {
      const name = cleanText(body.goal_name, 30);
      if (!name) throw new HttpError("Name your goal.");
      await env.DB.prepare("UPDATE nests SET goal_name = ?, goal_target = ? WHERE id = ?").bind(name, toCents(body.goal_target, "a target"), nestId).run();
    }
    return json({ ok: true });
  }

  if (path === "/api/nest/invite" && method === "POST") {
    const code = inviteCode();
    await env.DB.prepare("UPDATE nests SET invite_code = ? WHERE id = ?").bind(code, nestId).run();
    return json({ ok: true, invite_code: code });
  }

  if (path === "/api/nest/leave" && method === "POST") {
    await env.DB.prepare("DELETE FROM members WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId).run();
    const left = await env.DB.prepare("SELECT COUNT(*) AS n FROM members WHERE nest_id = ?").bind(nestId).first();
    if (left.n === 0) {
      await env.DB.batch(["entries", "settlements", "jar_moves", "recurring"].map((t) => env.DB.prepare(`DELETE FROM ${t} WHERE nest_id = ?`).bind(nestId))
        .concat([env.DB.prepare("DELETE FROM nests WHERE id = ?").bind(nestId)]));
    }
    return json({ ok: true });
  }

  // ----- savings jar -----
  if (path === "/api/jar" && method === "POST") {
    const cents = toCents(body.amount);
    const signed = body.direction === "out" ? -cents : cents;
    const nest = await env.DB.prepare("SELECT goal_saved FROM nests WHERE id = ?").bind(nestId).first();
    if (nest.goal_saved + signed < 0) throw new HttpError("You can't take out more than is in the jar.");
    await env.DB.batch([
      env.DB.prepare("INSERT INTO jar_moves (id, nest_id, member_id, amount_cents, created_at) VALUES (?, ?, ?, ?, ?)").bind(crypto.randomUUID(), nestId, user.id, signed, now()),
      env.DB.prepare("UPDATE nests SET goal_saved = goal_saved + ? WHERE id = ?").bind(signed, nestId),
    ]);
    return json({ ok: true });
  }
  const jarDel = path.match(/^\/api\/jar\/([0-9a-f-]{36})$/);
  if (jarDel && method === "DELETE") {
    const move = await env.DB.prepare("SELECT amount_cents FROM jar_moves WHERE id = ? AND nest_id = ?").bind(jarDel[1], nestId).first();
    if (!move) throw new HttpError("Not found.", 404);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM jar_moves WHERE id = ?").bind(jarDel[1]),
      env.DB.prepare("UPDATE nests SET goal_saved = MAX(0, goal_saved - ?) WHERE id = ?").bind(move.amount_cents, nestId),
    ]);
    return json({ ok: true });
  }

  // ----- settle up -----
  if (path === "/api/settlements" && method === "POST") {
    const ids = await memberIds(env, nestId);
    const from = String(body.from_id ?? ""), to = String(body.to_id ?? "");
    if (!ids.includes(from) || !ids.includes(to) || from === to) throw new HttpError("Pick who paid who.");
    await env.DB.prepare("INSERT INTO settlements (id, nest_id, from_id, to_id, amount_cents, date, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
      .bind(crypto.randomUUID(), nestId, from, to, toCents(body.amount), isDate(body.date) ? body.date : todayStr(), user.id, now()).run();
    return json({ ok: true }, 201);
  }
  const setDel = path.match(/^\/api\/settlements\/([0-9a-f-]{36})$/);
  if (setDel && method === "DELETE") {
    await env.DB.prepare("DELETE FROM settlements WHERE id = ? AND nest_id = ?").bind(setDel[1], nestId).run();
    return json({ ok: true });
  }

  // ----- entries -----
  if (path === "/api/entries" && method === "POST") {
    const e = await readEntry(env, nestId, user, body);
    let rid = null, occ = null;
    if (body.recurring_id) {
      const r = await env.DB.prepare("SELECT id FROM recurring WHERE id = ? AND nest_id = ?").bind(String(body.recurring_id), nestId).first();
      if (r && isDate(body.occ_date)) { rid = r.id; occ = body.occ_date; }
    }
    return json({ ok: true, id: await insertEntry(env, nestId, user, e, rid, occ) }, 201);
  }
  const entryId = path.match(/^\/api\/entries\/([0-9a-f-]{36})$/);
  if (entryId && method === "PATCH") {
    const existing = await env.DB.prepare("SELECT id FROM entries WHERE id = ? AND nest_id = ? AND (private = 0 OR member_id = ?)").bind(entryId[1], nestId, user.id).first();
    if (!existing) throw new HttpError("That entry doesn't exist anymore.", 404);
    const e = await readEntry(env, nestId, user, body);
    await env.DB.prepare(
      "UPDATE entries SET member_id = ?, type = ?, amount_cents = ?, label = ?, category = ?, shared = ?, split_mode = ?, split_value = ?, shares = ?, private = ?, date = ? WHERE id = ? AND nest_id = ?"
    ).bind(e.memberId, e.type, e.amount, e.label, e.category, e.shared, e.split.mode, e.split.value, e.shares, e.priv, e.date, entryId[1], nestId).run();
    return json({ ok: true });
  }
  if (entryId && method === "DELETE") {
    await env.DB.prepare("DELETE FROM entries WHERE id = ? AND nest_id = ? AND (private = 0 OR member_id = ?)").bind(entryId[1], nestId, user.id).run();
    return json({ ok: true });
  }

  // ----- bills & paydays -----
  async function readRecurring() {
    const e = await readEntry(env, nestId, user, body);
    const freq = FREQS.includes(body.freq) ? body.freq : null;
    if (!freq) throw new HttpError("Pick how often it repeats.");
    if (!isDate(body.date)) throw new HttpError("Pick the next date.");
    return { ...e, freq, anchor: body.date };
  }
  if (path === "/api/recurring" && method === "POST") {
    const r = await readRecurring();
    const id = crypto.randomUUID();
    await env.DB.prepare(
      "INSERT INTO recurring (id, nest_id, type, label, amount_cents, category, member_id, shared, split_mode, split_value, freq, anchor_date, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(id, nestId, r.type, r.label, r.amount, r.category, r.memberId, r.shared, r.split.mode, r.split.value, r.freq, r.anchor, user.id, now()).run();
    if (body.log_now) await insertEntry(env, nestId, user, { ...r, priv: 0 }, id, r.anchor);
    return json({ ok: true, id }, 201);
  }
  const recId = path.match(/^\/api\/recurring\/([0-9a-f-]{36})$/);
  if (recId && method === "PATCH") {
    const r = await readRecurring();
    await env.DB.prepare(
      "UPDATE recurring SET type = ?, label = ?, amount_cents = ?, category = ?, member_id = ?, shared = ?, split_mode = ?, split_value = ?, freq = ?, anchor_date = ? WHERE id = ? AND nest_id = ?"
    ).bind(r.type, r.label, r.amount, r.category, r.memberId, r.shared, r.split.mode, r.split.value, r.freq, r.anchor, recId[1], nestId).run();
    return json({ ok: true });
  }
  if (recId && method === "DELETE") {
    await env.DB.prepare("DELETE FROM recurring WHERE id = ? AND nest_id = ?").bind(recId[1], nestId).run();
    return json({ ok: true });
  }
  const recLog = path.match(/^\/api\/recurring\/([0-9a-f-]{36})\/log$/);
  if (recLog && method === "POST") {
    const r = await env.DB.prepare("SELECT * FROM recurring WHERE id = ? AND nest_id = ?").bind(recLog[1], nestId).first();
    if (!r) throw new HttpError("That bill doesn't exist anymore.", 404);
    if (!isDate(body.occ_date)) throw new HttpError("Bad date.");
    if (await env.DB.prepare("SELECT 1 FROM entries WHERE recurring_id = ? AND occ_date = ?").bind(r.id, body.occ_date).first())
      return json({ ok: true, already: true });
    const ids = await memberIds(env, nestId);
    const payer = ids.includes(r.member_id) ? r.member_id : user.id;
    const shared = r.shared && ids.length > 1 ? 1 : 0;
    const e = {
      type: r.type, amount: r.amount_cents, memberId: payer, shared, priv: 0,
      split: { mode: shared ? r.split_mode || "equal" : null, value: shared ? r.split_value : null },
      shares: shared ? JSON.stringify(computeShares(r.amount_cents, r.split_mode || "equal", r.split_value, payer, ids)) : null,
      category: r.category, label: r.label, date: todayStr(),
    };
    await insertEntry(env, nestId, user, e, r.id, body.occ_date);
    return json({ ok: true }, 201);
  }

  throw new HttpError("Not found.", 404);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);

    // CSRF protection: changes must come from our own site, as JSON
    if (request.method !== "GET") {
      let sameOrigin = false;
      try { sameOrigin = new URL(request.headers.get("origin")).host === url.host; } catch {}
      if (!sameOrigin) return fail("Request blocked.", 403);
      if (!(request.headers.get("content-type") || "").includes("application/json")) return fail("Expected JSON.", 415);
    }

    try {
      await ensureSchema(env);
      return await handle(request, env, url);
    } catch (e) {
      if (e instanceof HttpError) return fail(e.message, e.status);
      console.error(e);
      return fail("Something went wrong on our side. Try again.", 500);
    }
  },

  // daily cleanup (cron in wrangler.jsonc)
  async scheduled(_event, env) {
    await ensureSchema(env);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM sessions WHERE expires_at < ?").bind(now()),
      env.DB.prepare("DELETE FROM password_resets WHERE expires_at < ?").bind(now()),
      env.DB.prepare("DELETE FROM auth_attempts WHERE ts < ?").bind(now() - 86400),
    ]);
  },
};
