// Honeybun API — Cloudflare Worker + D1
// Static files in /public are served automatically; this Worker only handles /api/*.

const SESSION_DAYS = 30;
const COOKIE = "__Host-hb";
const PBKDF2_ITER = 100000; // max Workers allows
const MAX_MEMBERS = 8;

const CATEGORIES = ["home", "groc", "food", "date", "bills", "car", "fun", "pets", "other"];
const EMOJIS = ["🐰", "🐻", "🐱", "🐶", "🦊", "🐼", "🐨", "🐸", "🐧", "🦄", "🐥", "🐹"];
const COLORS = ["#FFD6E5", "#FFF0C2", "#DDF5E9", "#E4EDFF", "#EADFFF", "#FFE1CC"];
const ACCENTS = ["blueberry", "blush", "lavender", "honey"];

const SEC_HEADERS = {
  "x-content-type-options": "nosniff",
  "referrer-policy": "strict-origin-when-cross-origin",
  "x-frame-options": "DENY",
  "cache-control": "no-store",
};

const json = (data, status = 200, extra = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...SEC_HEADERS, ...extra },
  });
const fail = (message, status = 400) => json({ error: message }, status);

class HttpError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}

const now = () => Math.floor(Date.now() / 1000);
const enc = new TextEncoder();

// ---------- crypto helpers ----------
const b64u = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const fromB64u = (s) =>
  Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));

async function pbkdf2(password, salt, iterations) {
  const key = await crypto.subtle.importKey("raw", enc.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256);
  return new Uint8Array(bits);
}
async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, PBKDF2_ITER);
  return `pbkdf2$${PBKDF2_ITER}$${b64u(salt)}$${b64u(hash)}`;
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
// used when the email doesn't exist, so response time doesn't reveal that
const DUMMY_HASH = "pbkdf2$100000$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

async function sha256(text) {
  return b64u(await crypto.subtle.digest("SHA-256", enc.encode(text)));
}

function inviteCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 32 chars, no I/O/0/1
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes, (b) => alphabet[b % 32]).join("");
}

// ---------- sessions ----------
function readCookie(request, name) {
  const header = request.headers.get("cookie") || "";
  for (const part of header.split(/;\s*/)) {
    const i = part.indexOf("=");
    if (i > 0 && part.slice(0, i) === name) return part.slice(i + 1);
  }
  return null;
}
async function createSession(env, userId) {
  const token = b64u(crypto.getRandomValues(new Uint8Array(32)));
  const maxAge = SESSION_DAYS * 86400;
  await env.DB.prepare("INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)")
    .bind(await sha256(token), userId, now() + maxAge).run();
  return `${COOKIE}=${token}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;
}
const clearCookie = `${COOKIE}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`;

async function currentUser(request, env) {
  const token = readCookie(request, COOKIE);
  if (!token) return null;
  return env.DB.prepare(
    "SELECT u.id, u.email, u.name FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires_at > ?"
  ).bind(await sha256(token), now()).first();
}

// ---------- rate limiting ----------
async function limited(env, key, max, windowSec) {
  const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM auth_attempts WHERE key = ? AND ts > ?")
    .bind(key, now() - windowSec).first();
  return row.n >= max;
}
async function recordAttempt(env, key) {
  await env.DB.prepare("INSERT INTO auth_attempts (key, ts) VALUES (?, ?)").bind(key, now()).run();
}

// ---------- validation ----------
const cleanText = (v, max) => String(v ?? "").replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, max);
const isEmail = (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) && e.length <= 254;
const isDate = (d) => /^\d{4}-\d{2}-\d{2}$/.test(d) && !Number.isNaN(Date.parse(d));
function toCents(v) {
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0 || n > 10_000_000) throw new HttpError("Enter an amount between $0.01 and $10,000,000.");
  return Math.round(n * 100);
}

async function membership(env, userId) {
  return env.DB.prepare("SELECT nest_id FROM members WHERE user_id = ?").bind(userId).first();
}
async function requireNest(env, user) {
  const m = await membership(env, user.id);
  if (!m) throw new HttpError("You're not in a budget yet.", 404);
  return m.nest_id;
}

// ---------- routes ----------
async function handle(request, env, url) {
  const path = url.pathname;
  const method = request.method;
  const ip = request.headers.get("cf-connecting-ip") || "unknown";

  let body = {};
  if (method === "POST" || method === "PATCH") {
    body = await request.json().catch(() => null);
    if (!body || typeof body !== "object") throw new HttpError("Invalid request.");
  }

  // ----- public routes -----
  if (path === "/api/signup" && method === "POST") {
    if (await limited(env, "signup:" + ip, 10, 3600)) throw new HttpError("Too many sign-ups from here. Try again in an hour.", 429);
    const name = cleanText(body.name, 24);
    const email = cleanText(body.email, 254).toLowerCase();
    const password = String(body.password ?? "");
    if (!name) throw new HttpError("Enter your name.");
    if (!isEmail(email)) throw new HttpError("Enter a valid email address.");
    if (password.length < 8 || password.length > 200) throw new HttpError("Use a password with at least 8 characters.");
    await recordAttempt(env, "signup:" + ip);
    const exists = await env.DB.prepare("SELECT 1 FROM users WHERE email = ?").bind(email).first();
    if (exists) throw new HttpError("An account with that email already exists. Log in instead.", 409);
    const id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO users (id, email, name, pw, created_at) VALUES (?, ?, ?, ?, ?)")
      .bind(id, email, name, await hashPassword(password), now()).run();
    return json({ ok: true }, 201, { "set-cookie": await createSession(env, id) });
  }

  if (path === "/api/login" && method === "POST") {
    const email = cleanText(body.email, 254).toLowerCase();
    const password = String(body.password ?? "");
    if (await limited(env, "login:" + email, 10, 900) || await limited(env, "loginip:" + ip, 40, 900))
      throw new HttpError("Too many tries. Wait 15 minutes and try again.", 429);
    const user = await env.DB.prepare("SELECT id, pw FROM users WHERE email = ?").bind(email).first();
    const ok = await verifyPassword(password, user ? user.pw : DUMMY_HASH);
    if (!user || !ok) {
      await recordAttempt(env, "login:" + email);
      await recordAttempt(env, "loginip:" + ip);
      throw new HttpError("Wrong email or password.", 401);
    }
    return json({ ok: true }, 200, { "set-cookie": await createSession(env, user.id) });
  }

  if (path === "/api/logout" && method === "POST") {
    const token = readCookie(request, COOKIE);
    if (token) await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(await sha256(token)).run();
    return json({ ok: true }, 200, { "set-cookie": clearCookie });
  }

  // ----- everything below needs a logged-in user -----
  const user = await currentUser(request, env);
  if (!user) throw new HttpError("Please log in.", 401);

  if (path === "/api/me" && method === "GET") {
    const m = await membership(env, user.id);
    return json({ user, nest_id: m ? m.nest_id : null });
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
    const name = cleanText(body.name, 24);
    await env.DB.batch([
      env.DB.prepare("INSERT INTO nests (id, name, invite_code, created_by, created_at) VALUES (?, ?, ?, ?, ?)")
        .bind(id, name, inviteCode(), user.id, now()),
      env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at) VALUES (?, ?, ?, ?, ?)")
        .bind(id, user.id, EMOJIS[0], COLORS[0], now()),
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
    const members = await env.DB.prepare("SELECT emoji, color FROM members WHERE nest_id = ?").bind(nest.id).all();
    if (members.results.length >= MAX_MEMBERS) throw new HttpError("This budget is full.", 409);
    const usedE = members.results.map((m) => m.emoji), usedC = members.results.map((m) => m.color);
    const emoji = EMOJIS.find((e) => !usedE.includes(e)) || EMOJIS[0];
    const color = COLORS.find((c) => !usedC.includes(c)) || COLORS[0];
    await env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at) VALUES (?, ?, ?, ?, ?)")
      .bind(nest.id, user.id, emoji, color, now()).run();
    return json({ ok: true, nest_id: nest.id });
  }

  if (path === "/api/nest" && method === "GET") {
    const nestId = await requireNest(env, user);
    const month = url.searchParams.get("month") || "";
    if (!/^\d{4}-\d{2}$/.test(month)) throw new HttpError("Bad month.");
    const [nest, members, entries] = await env.DB.batch([
      env.DB.prepare("SELECT id, name, invite_code, accent, goal_name, goal_target, goal_saved FROM nests WHERE id = ?").bind(nestId),
      env.DB.prepare("SELECT u.id, u.name, m.emoji, m.color FROM members m JOIN users u ON u.id = m.user_id WHERE m.nest_id = ? ORDER BY m.joined_at").bind(nestId),
      env.DB.prepare("SELECT id, member_id, type, amount_cents, label, category, shared, date, created_at FROM entries WHERE nest_id = ? AND date >= ? AND date <= ? ORDER BY date DESC, created_at DESC")
        .bind(nestId, month + "-01", month + "-31"),
    ]);
    return json({ me: user, nest: nest.results[0], members: members.results, entries: entries.results });
  }

  if (path === "/api/nest" && method === "PATCH") {
    const nestId = await requireNest(env, user);
    if (body.name !== undefined)
      await env.DB.prepare("UPDATE nests SET name = ? WHERE id = ?").bind(cleanText(body.name, 24), nestId).run();
    if (body.accent !== undefined) {
      if (!ACCENTS.includes(body.accent)) throw new HttpError("Unknown theme.");
      await env.DB.prepare("UPDATE nests SET accent = ? WHERE id = ?").bind(body.accent, nestId).run();
    }
    if (body.goal_name !== undefined || body.goal_target !== undefined) {
      const name = cleanText(body.goal_name, 30);
      if (!name) throw new HttpError("Name your goal.");
      await env.DB.prepare("UPDATE nests SET goal_name = ?, goal_target = ? WHERE id = ?").bind(name, toCents(body.goal_target), nestId).run();
    }
    return json({ ok: true });
  }

  if (path === "/api/nest/jar" && method === "POST") {
    const nestId = await requireNest(env, user);
    await env.DB.prepare("UPDATE nests SET goal_saved = goal_saved + ? WHERE id = ?").bind(toCents(body.amount), nestId).run();
    return json({ ok: true });
  }

  if (path === "/api/nest/invite" && method === "POST") {
    const nestId = await requireNest(env, user);
    const code = inviteCode();
    await env.DB.prepare("UPDATE nests SET invite_code = ? WHERE id = ?").bind(code, nestId).run();
    return json({ ok: true, invite_code: code });
  }

  if (path === "/api/nest/leave" && method === "POST") {
    const nestId = await requireNest(env, user);
    await env.DB.prepare("DELETE FROM members WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId).run();
    const left = await env.DB.prepare("SELECT COUNT(*) AS n FROM members WHERE nest_id = ?").bind(nestId).first();
    if (left.n === 0) {
      await env.DB.batch([
        env.DB.prepare("DELETE FROM entries WHERE nest_id = ?").bind(nestId),
        env.DB.prepare("DELETE FROM nests WHERE id = ?").bind(nestId),
      ]);
    }
    return json({ ok: true });
  }

  if (path === "/api/entries" && method === "POST") {
    const nestId = await requireNest(env, user);
    const type = body.type === "income" ? "income" : body.type === "expense" ? "expense" : null;
    if (!type) throw new HttpError("Bad entry type.");
    const amount = toCents(body.amount);
    const memberId = String(body.member_id ?? "");
    const isMember = await env.DB.prepare("SELECT 1 FROM members WHERE nest_id = ? AND user_id = ?").bind(nestId, memberId).first();
    if (!isMember) throw new HttpError("Pick who paid.");
    const category = type === "expense" ? (CATEGORIES.includes(body.category) ? body.category : "other") : null;
    const label = cleanText(body.label, 40) || (type === "income" ? "Paycheck" : "Expense");
    const date = isDate(body.date) ? body.date : new Date().toISOString().slice(0, 10);
    const id = crypto.randomUUID();
    await env.DB.prepare(
      "INSERT INTO entries (id, nest_id, member_id, type, amount_cents, label, category, shared, date, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ).bind(id, nestId, memberId, type, amount, label, category, type === "expense" && body.shared ? 1 : 0, date, user.id, now()).run();
    return json({ ok: true, id }, 201);
  }

  const del = path.match(/^\/api\/entries\/([0-9a-f-]{36})$/);
  if (del && method === "DELETE") {
    const nestId = await requireNest(env, user);
    await env.DB.prepare("DELETE FROM entries WHERE id = ? AND nest_id = ?").bind(del[1], nestId).run();
    return json({ ok: true });
  }

  throw new HttpError("Not found.", 404);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);

    // CSRF protection: state-changing requests must come from our own site as JSON
    if (request.method !== "GET") {
      let sameOrigin = false;
      try { sameOrigin = new URL(request.headers.get("origin")).host === url.host; } catch {}
      if (!sameOrigin) return fail("Request blocked.", 403);
      const type = request.headers.get("content-type") || "";
      if (!type.includes("application/json")) return fail("Expected JSON.", 415);
    }

    try {
      return await handle(request, env, url);
    } catch (e) {
      if (e instanceof HttpError) return fail(e.message, e.status);
      console.error(e);
      return fail("Something went wrong on our side. Try again.", 500);
    }
  },

  // optional daily cleanup (enable with a cron trigger)
  async scheduled(_event, env) {
    await env.DB.batch([
      env.DB.prepare("DELETE FROM sessions WHERE expires_at < ?").bind(now()),
      env.DB.prepare("DELETE FROM auth_attempts WHERE ts < ?").bind(now() - 86400),
    ]);
  },
};
