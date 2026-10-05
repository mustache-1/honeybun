// Honeybun API — Cloudflare Worker + D1
// Static files in /public are served automatically; this Worker only handles /api/*.

const SESSION_DAYS = 30;
const COOKIE = "__Host-hb";
const PBKDF2_ITER = 100000; // the most Workers allows
const MAX_MEMBERS = 8;
const RESET_MINUTES = 60;

const CATEGORIES = ["home", "groc", "food", "date", "bills", "subs", "car", "fun", "pets", "debt", "other"];
const GOAL_EMOJIS = ["🍯", "✈️", "🏠", "💍", "🚗", "🎓", "🐶", "🎄", "🛟", "🎁"];
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
  `CREATE TABLE IF NOT EXISTS nests (id TEXT PRIMARY KEY, name TEXT NOT NULL DEFAULT '', invite_code TEXT NOT NULL UNIQUE, accent TEXT NOT NULL DEFAULT 'blueberry', goal_name TEXT NOT NULL DEFAULT 'Weekend getaway', goal_target INTEGER NOT NULL DEFAULT 80000, goal_saved INTEGER NOT NULL DEFAULT 0, goals_migrated INTEGER NOT NULL DEFAULT 0, created_by TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS members (nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, emoji TEXT NOT NULL, color TEXT NOT NULL, joined_at INTEGER NOT NULL, setup_done INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (nest_id, user_id))`,
  `CREATE TABLE IF NOT EXISTS entries (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, member_id TEXT NOT NULL, type TEXT NOT NULL CHECK (type IN ('income','expense')), amount_cents INTEGER NOT NULL CHECK (amount_cents > 0), label TEXT NOT NULL, category TEXT, shared INTEGER NOT NULL DEFAULT 0, date TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL, split_mode TEXT, split_value INTEGER, shares TEXT, private INTEGER NOT NULL DEFAULT 0, recurring_id TEXT, occ_date TEXT)`,
  `CREATE INDEX IF NOT EXISTS idx_entries_nest_date ON entries(nest_id, date)`,
  `CREATE TABLE IF NOT EXISTS auth_attempts (key TEXT NOT NULL, ts INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_attempts ON auth_attempts(key, ts)`,
  `CREATE TABLE IF NOT EXISTS password_resets (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS verify_tokens (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, expires_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS settlements (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, from_id TEXT NOT NULL, to_id TEXT NOT NULL, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0), date TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_settlements_nest ON settlements(nest_id)`,
  `CREATE TABLE IF NOT EXISTS jar_moves (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, member_id TEXT NOT NULL, amount_cents INTEGER NOT NULL, created_at INTEGER NOT NULL, goal_id TEXT)`,
  `CREATE INDEX IF NOT EXISTS idx_jar_nest ON jar_moves(nest_id)`,
  `CREATE TABLE IF NOT EXISTS recurring (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, type TEXT NOT NULL CHECK (type IN ('income','expense')), label TEXT NOT NULL, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0), category TEXT, member_id TEXT NOT NULL, shared INTEGER NOT NULL DEFAULT 0, split_mode TEXT, split_value INTEGER, freq TEXT NOT NULL, anchor_date TEXT NOT NULL, created_by TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_recurring_nest ON recurring(nest_id)`,
  `CREATE TABLE IF NOT EXISTS goals (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, name TEXT NOT NULL, emoji TEXT NOT NULL, target_cents INTEGER NOT NULL, saved_cents INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_goals_nest ON goals(nest_id)`,
  `CREATE TABLE IF NOT EXISTS budgets (nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, category TEXT NOT NULL, limit_cents INTEGER NOT NULL, PRIMARY KEY (nest_id, category))`,
  `CREATE TABLE IF NOT EXISTS debts (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, name TEXT NOT NULL, start_cents INTEGER NOT NULL, apr_bp INTEGER NOT NULL DEFAULT 0, min_cents INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_debts_nest ON debts(nest_id)`,
  `CREATE TABLE IF NOT EXISTS debt_payments (id TEXT PRIMARY KEY, debt_id TEXT NOT NULL, nest_id TEXT NOT NULL, member_id TEXT NOT NULL, amount_cents INTEGER NOT NULL, date TEXT NOT NULL, entry_id TEXT, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_debtpay_nest ON debt_payments(nest_id)`,
  `CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, nest_id TEXT, kind TEXT NOT NULL, data TEXT NOT NULL DEFAULT '{}', dedupe TEXT NOT NULL, created_at INTEGER NOT NULL, read_at INTEGER)`,
  `CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_dedupe ON messages(user_id, dedupe)`,
  `CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id, created_at)`,
  `CREATE TABLE IF NOT EXISTS api_keys (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, created_at INTEGER NOT NULL, last_used INTEGER, uses INTEGER NOT NULL DEFAULT 0)`,
  `CREATE TABLE IF NOT EXISTS passkeys (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, public_key TEXT NOT NULL, alg INTEGER NOT NULL, counter INTEGER NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, last_used INTEGER)`,
  `CREATE INDEX IF NOT EXISTS idx_passkeys_user ON passkeys(user_id)`,
  `CREATE TABLE IF NOT EXISTS challenges (id TEXT PRIMARY KEY, user_id TEXT, kind TEXT NOT NULL, expires_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS push_subs (endpoint TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_push_user ON push_subs(user_id)`,
  // iPhone app: APNs device tokens, and per-device tokens the widget and Siri shortcuts use instead of a login cookie
  `CREATE TABLE IF NOT EXISTS apns_tokens (token TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_apns_user ON apns_tokens(user_id)`,
  // your own spending categories (name + emoji), per household
  `CREATE TABLE IF NOT EXISTS custom_categories (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, name TEXT NOT NULL, emoji TEXT NOT NULL, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_custom_cat_nest ON custom_categories(nest_id)`,
  // shared shopping list
  `CREATE TABLE IF NOT EXISTS shopping_items (id TEXT PRIMARY KEY, nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, label TEXT NOT NULL, added_by TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, done_by TEXT, created_at INTEGER NOT NULL, done_at INTEGER)`,
  `CREATE INDEX IF NOT EXISTS idx_shopping_nest ON shopping_items(nest_id, done)`,
  // carrying a month's leftover (or shortfall) into the next month; one decision per household per month
  `CREATE TABLE IF NOT EXISTS month_carry (nest_id TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE, month TEXT NOT NULL, amount_cents INTEGER NOT NULL, accepted INTEGER NOT NULL DEFAULT 1, decided_by TEXT, created_at INTEGER NOT NULL, PRIMARY KEY (nest_id, month))`,
  `CREATE TABLE IF NOT EXISTS app_tokens (token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, created_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS idx_app_tokens_user ON app_tokens(user_id)`,
  // referrals: invite friends, get a gift card for every REF_GOAL who stick around
  `CREATE TABLE IF NOT EXISTS referrals (id TEXT PRIMARY KEY, referrer_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, referred_id TEXT NOT NULL UNIQUE, referred_name TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending', reason TEXT, created_at INTEGER NOT NULL, decided_at INTEGER)`,
  `CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id)`,
  `CREATE TABLE IF NOT EXISTS devices (user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, hash TEXT NOT NULL, first_seen INTEGER NOT NULL, PRIMARY KEY (user_id, hash))`,
  `CREATE INDEX IF NOT EXISTS idx_devices_hash ON devices(hash)`,
  `CREATE TABLE IF NOT EXISTS rewards (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, amount_cents INTEGER NOT NULL, referrals INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at INTEGER NOT NULL, sent_at INTEGER, notified INTEGER NOT NULL DEFAULT 0)`,
];
const NEW_COLUMNS = {
  users: [["recovery_hash", "TEXT"], ["email_verified", "INTEGER NOT NULL DEFAULT 0"], ["tz", "TEXT"], ["lang", "TEXT NOT NULL DEFAULT 'en'"],
    ["mail_bills", "INTEGER NOT NULL DEFAULT 1"], ["mail_streak", "INTEGER NOT NULL DEFAULT 1"], ["mail_weekly", "INTEGER NOT NULL DEFAULT 1"],
    ["last_bill_mail", "TEXT"], ["last_streak_mail", "TEXT"], ["last_week_mail", "TEXT"], ["unsub_token", "TEXT"], ["last_bill_push", "TEXT"], ["last_streak_push", "TEXT"], ["last_tip_push", "TEXT"], ["ref_code", "TEXT"], ["referred_by", "TEXT"], ["apple_sub", "TEXT"], ["pw_known", "INTEGER NOT NULL DEFAULT 1"]],
  entries: [["split_mode", "TEXT"], ["split_value", "INTEGER"], ["shares", "TEXT"], ["private", "INTEGER NOT NULL DEFAULT 0"], ["recurring_id", "TEXT"], ["occ_date", "TEXT"]],
  members: [["setup_done", "INTEGER NOT NULL DEFAULT 1"], ["xp", "INTEGER NOT NULL DEFAULT 0"], ["streak", "INTEGER NOT NULL DEFAULT 0"],
    ["best_streak", "INTEGER NOT NULL DEFAULT 0"], ["last_day", "TEXT"], ["day_xp", "INTEGER NOT NULL DEFAULT 0"],
    ["week_key", "TEXT"], ["week_xp", "INTEGER NOT NULL DEFAULT 0"], ["logs", "INTEGER NOT NULL DEFAULT 0"], ["inbox_gen_at", "INTEGER NOT NULL DEFAULT 0"]],
  nests: [["goals_migrated", "INTEGER NOT NULL DEFAULT 0"], ["kind", "TEXT NOT NULL DEFAULT 'couple'"], ["rollover", "INTEGER NOT NULL DEFAULT 0"], ["rollover_since", "TEXT"], ["joint", "INTEGER NOT NULL DEFAULT 0"], ["carry_mode", "TEXT NOT NULL DEFAULT 'ask'"]],
  recurring: [["prev_amount_cents", "INTEGER"], ["price_changed_at", "TEXT"]],
  jar_moves: [["goal_id", "TEXT"]],
};

let schemaReady = null;
function ensureSchema(env) {
  if (!schemaReady) schemaReady = migrate(env).catch((e) => { schemaReady = null; throw e; });
  return schemaReady;
}
async function migrate(env) {
  await env.DB.batch(TABLES.map((s) => env.DB.prepare(s)));
  for (const [table, columns] of Object.entries(NEW_COLUMNS)) {
    const have = (await env.DB.prepare(`PRAGMA table_info(${table})`).all()).results.map((c) => c.name);
    for (const [name, type] of columns) {
      if (have.includes(name)) continue;
      try { await env.DB.prepare(`ALTER TABLE ${table} ADD COLUMN ${name} ${type}`).run(); }
      catch (e) { if (!String(e.message).includes("duplicate column")) throw e; }
    }
  }
  await env.DB.batch([
    env.DB.prepare("CREATE INDEX IF NOT EXISTS idx_entries_occ ON entries(recurring_id, occ_date)"),
    // move the old single savings jar into the new goals list (runs once per budget)
    env.DB.prepare(`INSERT INTO goals (id, nest_id, name, emoji, target_cents, saved_cents, created_at)
      SELECT lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-' || hex(randomblob(2)) || '-' || hex(randomblob(2)) || '-' || hex(randomblob(6))),
             id, goal_name, '🍯', goal_target, goal_saved, created_at FROM nests WHERE goals_migrated = 0`),
    env.DB.prepare("UPDATE jar_moves SET goal_id = (SELECT g.id FROM goals g WHERE g.nest_id = jar_moves.nest_id ORDER BY g.created_at LIMIT 1) WHERE goal_id IS NULL"),
    env.DB.prepare("UPDATE nests SET goals_migrated = 1 WHERE goals_migrated = 0"),
    env.DB.prepare("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_ref ON users(ref_code)"),
    env.DB.prepare("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_apple ON users(apple_sub)"),
  ]);
}

// ---------- Bun's inbox (in-app messages) ----------
// Messages are stored as a kind + small data object; the app turns them into friendly text in the right language.
async function postMessage(env, userId, nestId, kind, data, dedupe) {
  await env.DB.prepare("INSERT OR IGNORE INTO messages (id, user_id, nest_id, kind, data, dedupe, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
    .bind(crypto.randomUUID(), userId, nestId, kind, JSON.stringify(data || {}), dedupe || kind + ":" + crypto.randomUUID(), now()).run();
}
async function postToOthers(env, nestId, exceptId, kind, data, dedupe) {
  const ids = (await env.DB.prepare("SELECT user_id FROM members WHERE nest_id = ? AND user_id != ?").bind(nestId, exceptId).all()).results.map((r) => r.user_id);
  const langs = Object.fromEntries((await env.DB.prepare("SELECT id, lang FROM users WHERE id IN (SELECT user_id FROM members WHERE nest_id = ?)").bind(nestId).all()).results.map((r) => [r.id, r.lang]));
  for (const id of ids) {
    await postMessage(env, id, nestId, kind, data, dedupe);
    try { await sendPush(env, id, pushText(kind, data, langs[id])); } catch (e) { console.error("push", e.message); }
  }
}

// ---------- Web Push (no payload: the service worker asks /api/push/latest for the text) ----------
const PUSH_TEXT = {
  en: { joint_entry: (d) => `${d.name} added ${d.label} (${money(d.amount)}).`, shared_expense: (d) => `${d.name} added ${money(d.amount)} for ${d.label}, split with you.`, joined: (d) => `${d.name} joined your budget 🎉`,
        carry_ask: (d) => `New month! ${d.from} ended at ${d.neg ? "-" : ""}${money(d.amount)}. Open Honeybun to carry it over or start fresh.`,
        carry_done: (d) => d.accepted ? `${d.name} carried over ${d.neg ? "-" : ""}${money(d.amount)} from last month.` : `${d.name} started this month fresh.`,
        carry_auto: (d) => `New month! ${d.neg ? "-" : ""}${money(d.amount)} from ${d.from} was carried over for you.`,
        joint: (d) => d.on ? `${d.name} turned on Joint account. Everything adds up together now.` : `${d.name} turned off Joint account.`,
        bills: (d) => d.n === 1 ? `${d.label} (${money(d.amount)}) is due ${d.when}.` : `${d.n} bills are due in the next 3 days.`,
        streak: (d) => `Log one thing today to keep your ${d.streak}-day hop streak 🐾`, tip: (d) => d.text, other: () => "Bun has something for you 🐰" },
  es: { joint_entry: (d) => `${d.name} agregó ${d.label} (${money(d.amount)}).`, shared_expense: (d) => `${d.name} agregó ${money(d.amount)} de ${d.label}, dividido contigo.`, joined: (d) => `${d.name} se unió a tu presupuesto 🎉`,
        carry_ask: (d) => `¡Nuevo mes! ${d.from} terminó en ${d.neg ? "-" : ""}${money(d.amount)}. Abre Honeybun para trasladarlo o empezar de cero.`,
        carry_done: (d) => d.accepted ? `${d.name} trasladó ${d.neg ? "-" : ""}${money(d.amount)} del mes pasado.` : `${d.name} empezó este mes de cero.`,
        joint: (d) => d.on ? `${d.name} activó la cuenta conjunta. Ahora todo se suma junto.` : `${d.name} desactivó la cuenta conjunta.`,
        bills: (d) => d.n === 1 ? `${d.label} (${money(d.amount)}) vence ${d.when}.` : `${d.n} facturas vencen en los próximos 3 días.`,
        streak: (d) => `Registra algo hoy para mantener tu racha de ${d.streak} días 🐾`, tip: (d) => d.text, other: () => "Bun tiene algo para ti 🐰" },
  zh: { joint_entry: (d) => `${d.name} 添加了 ${d.label}（${money(d.amount)}）。`, shared_expense: (d) => `${d.name} 记了一笔 ${money(d.amount)}（${d.label}），和你分摊。`, joined: (d) => `${d.name} 加入了你的预算 🎉`,
        carry_ask: (d) => `新的一个月！${d.from} 结余 ${d.neg ? "-" : ""}${money(d.amount)}。打开 Honeybun 选择结转或重新开始。`,
        carry_done: (d) => d.accepted ? `${d.name} 把上月的 ${d.neg ? "-" : ""}${money(d.amount)} 结转到了本月。` : `${d.name} 选择本月重新开始。`,
        joint: (d) => d.on ? `${d.name} 开启了共同账户，所有金额合并计算。` : `${d.name} 关闭了共同账户。`,
        bills: (d) => d.n === 1 ? `${d.label}（${money(d.amount)}）${d.when}到期。` : `未来 3 天有 ${d.n} 笔账单到期。`,
        streak: (d) => `今天记一笔，保持你 ${d.streak} 天的连续记录 🐾`, tip: (d) => d.text, other: () => "Bun 有话对你说 🐰" },
};
const pushText = (kind, data, lang) => { const T = PUSH_TEXT[lang] || PUSH_TEXT.en; return { kind, body: (T[kind] || T.other)(data || {}) }; };

async function vapidHeaders(env, endpoint) {
  const origin = new URL(endpoint).origin, exp = now() + 12 * 3600;
  const jwk = JSON.parse(env.VAPID_PRIVATE_KEY);
  const key = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const part = (o) => b64u(enc.encode(JSON.stringify(o)));
  const input = `${part({ typ: "JWT", alg: "ES256" })}.${part({ aud: origin, exp, sub: "mailto:help@honeybun.me" })}`;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(input));
  return { authorization: `vapid t=${input}.${b64u(sig)}, k=${env.VAPID_PUBLIC_KEY}`, ttl: "86400", urgency: "normal" };
}
// Send a "something's new" push to all of a person's devices. The text is stored so the service worker can fetch it.
async function sendPush(env, userId, text) {
  await sendApns(env, userId, text).catch((e) => console.error("apns", e.message));
  if (!env.VAPID_PRIVATE_KEY || !env.VAPID_PUBLIC_KEY) return;
  const subs = (await env.DB.prepare("SELECT endpoint FROM push_subs WHERE user_id = ?").bind(userId).all()).results;
  if (!subs.length) return;
  await env.DB.prepare("INSERT OR REPLACE INTO challenges (id, user_id, kind, expires_at) VALUES (?, ?, ?, ?)")
    .bind("push:" + userId, userId, JSON.stringify(text), now() + 3600).run();
  for (const sub of subs) {
    try {
      const res = await fetch(sub.endpoint, { method: "POST", headers: await vapidHeaders(env, sub.endpoint) });
      if (res.status === 404 || res.status === 410) await env.DB.prepare("DELETE FROM push_subs WHERE endpoint = ?").bind(sub.endpoint).run();
      else if (!res.ok) console.error("push failed", res.status, await res.text().catch(() => ""));
    } catch (e) { console.error("push error", e.message); }
  }
}

// ---------- Apple push (APNs) for the iPhone app. Needs APNS_KEY (the .p8 text), APNS_KEY_ID, APNS_TEAM_ID; APNS_TOPIC defaults to the app's bundle id. ----------
let apnsJwt = null;
async function apnsToken(env) {
  if (apnsJwt && now() - apnsJwt.at < 3000) return apnsJwt.jwt;
  const pem = String(env.APNS_KEY).replace(/\\n/g, "\n").replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const part = (o) => b64u(enc.encode(JSON.stringify(o)));
  const input = `${part({ alg: "ES256", kid: env.APNS_KEY_ID })}.${part({ iss: env.APNS_TEAM_ID, iat: now() })}`;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(input));
  apnsJwt = { at: now(), jwt: `${input}.${b64u(sig)}` };
  return apnsJwt.jwt;
}
async function sendApns(env, userId, text) {
  if (!env.APNS_KEY || !env.APNS_KEY_ID || !env.APNS_TEAM_ID) return;
  const toks = (await env.DB.prepare("SELECT token FROM apns_tokens WHERE user_id = ?").bind(userId).all()).results;
  if (!toks.length) return;
  const jwt = await apnsToken(env), topic = env.APNS_TOPIC || "me.honeybun.app";
  const hosts = env.APNS_ENV === "sandbox" ? ["api.sandbox.push.apple.com", "api.push.apple.com"] : ["api.push.apple.com", "api.sandbox.push.apple.com"];
  const payload = JSON.stringify({ aps: { alert: { title: "Honeybun", body: text.body }, sound: "default" }, kind: text.kind });
  for (const t of toks) {
    let gone = false;
    for (const h of hosts) {
      try {
        const res = await fetch(`https://${h}/3/device/${t.token}`, { method: "POST", headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" }, body: payload });
        if (res.ok) { gone = false; break; }
        const why = await res.text().catch(() => "");
        // a token made for the other APNs server says BadDeviceToken: try the other one before giving up on it
        gone = res.status === 410 || /BadDeviceToken|Unregistered|DeviceTokenNotForTopic/.test(why);
        if (!gone) { console.error("apns failed", res.status, why); break; }
      } catch (e) { console.error("apns error", e.message); break; }
    }
    if (gone) await env.DB.prepare("DELETE FROM apns_tokens WHERE token = ?").bind(t.token).run();
  }
}
const STREAK_MILESTONES = [3, 7, 14, 30, 50, 100, 200, 365];
async function generateInbox(env, request, user, nestId, force) {
  const m = await env.DB.prepare("SELECT streak, last_day, inbox_gen_at FROM members WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId).first();
  if (!m || (!force && now() - m.inbox_gen_at < 600)) return;
  await env.DB.prepare("UPDATE members SET inbox_gen_at = ? WHERE user_id = ? AND nest_id = ?").bind(now(), user.id, nestId).run();
  const u = await env.DB.prepare("SELECT name, tz, created_at FROM users WHERE id = ?").bind(user.id).first();
  const day = localDay(request), L = localNow(u.tz), msgs = [];
  const add = (kind, data, dedupe) => msgs.push([kind, data, dedupe]);
  const any = await env.DB.prepare("SELECT 1 FROM messages WHERE user_id = ? LIMIT 1").bind(user.id).first();
  if (!any) add("welcome", { name: u.name }, "welcome");
  // referral nudges: once after a couple of days, then monthly while nobody has signed up yet
  const age = now() - (u.created_at || now());
  if (age >= 2 * 86400) add("ref_intro", { goal: REF_GOAL, amount: REF_REWARD_CENTS }, "ref_intro");
  if (age >= 14 * 86400 && L.hour >= 10) {
    const [had, intro] = await env.DB.batch([
      env.DB.prepare("SELECT 1 FROM referrals WHERE referrer_id = ? LIMIT 1").bind(user.id),
      env.DB.prepare("SELECT created_at FROM messages WHERE user_id = ? AND dedupe = 'ref_intro'").bind(user.id),
    ]);
    const introAt = intro.results[0]?.created_at;
    if (!had.results.length && introAt && now() - introAt > 20 * 86400) add("ref_nudge", { goal: REF_GOAL, amount: REF_REWARD_CENTS }, "ref_nudge:" + day.slice(0, 7));
  }

  const [rec, logged, spend, budgets] = await env.DB.batch([
    env.DB.prepare("SELECT id, type, label, amount_cents, member_id, shared, freq, anchor_date FROM recurring WHERE nest_id = ?").bind(nestId),
    env.DB.prepare("SELECT recurring_id, occ_date FROM entries WHERE nest_id = ? AND recurring_id IS NOT NULL AND occ_date >= ?").bind(nestId, sDay(pDay(day) - 40 * dayMs)),
    env.DB.prepare("SELECT category, SUM(amount_cents) AS c FROM entries WHERE nest_id = ? AND type = 'expense' AND date >= ? AND date <= ? AND (private = 0 OR member_id = ?) GROUP BY category")
      .bind(nestId, day.slice(0, 7) + "-01", day.slice(0, 7) + "-31", user.id),
    env.DB.prepare("SELECT category, limit_cents FROM budgets WHERE nest_id = ?").bind(nestId),
  ]);
  const done = new Set(logged.results.map((l) => l.recurring_id + "|" + l.occ_date));
  for (const r of rec.results) {
    const mine = r.type === "income" ? r.member_id === user.id : r.shared || r.member_id === user.id;
    if (!mine) continue;
    for (const occ of occurrencesS(r, sDay(pDay(day) - 7 * dayMs), sDay(pDay(day) + 3 * dayMs))) {
      if (done.has(r.id + "|" + occ)) continue;
      const diff = Math.round((pDay(occ) - pDay(day)) / dayMs);
      const data = { rid: r.id, occ, label: r.label, amount: r.amount_cents };
      if (r.type === "income") { if (diff === 0) add("payday", data, `payday:${r.id}:${occ}`); continue; }
      if (diff < 0) add("bill_late", data, `late:${r.id}:${occ}`);
      else if (diff === 0) add("bill_today", data, `today:${r.id}:${occ}`);
      else add("bill_soon", data, `soon:${r.id}:${occ}`);
    }
  }
  // streak about to end (evening, local time)
  if (L.hour >= 18 && m.streak >= 2 && m.last_day === sDay(pDay(day) - dayMs)) add("streak_risk", { n: m.streak }, `risk:${day}`);
  // budgets at 80% / over
  const spent = Object.fromEntries(spend.results.map((r) => [r.category, r.c]));
  const month = day.slice(0, 7);
  const carry = await budgetCarry(env, nestId, user.id, month);
  for (const b of budgets.results) {
    b.limit_cents += carry[b.category] || 0;
    const sp = spent[b.category] || 0;
    if (sp > b.limit_cents) add("budget_over", { cat: b.category, over: sp - b.limit_cents }, `over:${b.category}:${month}`);
    else if (sp >= b.limit_cents * 0.8) add("budget_warn", { cat: b.category, spent: sp, limit: b.limit_cents }, `warn:${b.category}:${month}`);
  }
  // weekly recap on Mondays
  if (L.weekday === "Mon") {
    const from = sDay(pDay(day) - 7 * dayMs), to = sDay(pDay(day) - dayMs);
    const [wk, mem] = await env.DB.batch([
      env.DB.prepare("SELECT category, SUM(amount_cents) AS c FROM entries WHERE nest_id = ? AND type = 'expense' AND date >= ? AND date <= ? AND (private = 0 OR member_id = ?) GROUP BY category ORDER BY c DESC")
        .bind(nestId, from, to, user.id),
      env.DB.prepare("SELECT week_key, week_xp FROM members WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId),
    ]);
    const total = wk.results.reduce((a, r) => a + r.c, 0), me = mem.results[0] || {};
    if (total > 0) add("week", { spent: total, cat: wk.results[0]?.category || null, xp: me.week_key === from ? me.week_xp : 0 }, `week:${from}`);
  }
  for (const [k, d, dd] of msgs) await postMessage(env, user.id, nestId, k, d, dd);
}

// ---------- referrals ----------
// Share your link (/r/CODE). A friend counts once they have confirmed their email, logged on 4+ different days,
// and are still logging a week after signing up. They can't be on one of your devices or in your own budget.
// Every REF_GOAL friends who count = one gift card (sent by hand; the owner gets an email).
const REF_GOAL = 10, REF_REWARD_CENTS = 1000, REF_DAYS = 7, REF_ACTIVE_DAYS = 4, REF_EXPIRE_DAYS = 30;
const DEV_COOKIE = "__Host-hbd";
function deviceIds(request) {
  // a long-lived cookie set by the server + an id the app keeps in local storage; either one identifies a device
  const out = [];
  const c = readCookie(request, DEV_COOKIE), h = request.headers.get("x-hb-device");
  for (const v of [c, h]) if (v && /^[A-Za-z0-9_-]{16,64}$/.test(v) && !out.includes(v)) out.push(v);
  return out;
}
async function deviceHashes(request) { return Promise.all(deviceIds(request).map((d) => sha256("dev:" + d))); }
async function rememberDevices(env, request, userId) {
  const hs = await deviceHashes(request);
  if (hs.length) await env.DB.batch(hs.map((h) => env.DB.prepare("INSERT OR IGNORE INTO devices (user_id, hash, first_seen) VALUES (?, ?, ?)").bind(userId, h, now())));
}
async function refCode(env, userId) {
  const row = await env.DB.prepare("SELECT ref_code FROM users WHERE id = ?").bind(userId).first();
  if (row?.ref_code) return row.ref_code;
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  for (let i = 0; i < 5; i++) {
    const code = Array.from(crypto.getRandomValues(new Uint8Array(7)), (b) => alphabet[b % 32]).join("");
    try {
      await env.DB.prepare("UPDATE users SET ref_code = ? WHERE id = ? AND ref_code IS NULL").bind(code, userId).run();
      const again = await env.DB.prepare("SELECT ref_code FROM users WHERE id = ?").bind(userId).first();
      if (again?.ref_code) return again.ref_code;
    } catch (e) { if (!String(e.message).includes("UNIQUE")) throw e; }
  }
  throw new HttpError("Couldn't make your link. Try again.", 500);
}
async function recordReferral(env, request, newUser, code) {
  code = String(code || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 16);
  if (code.length < 4) return;
  const ref = await env.DB.prepare("SELECT id FROM users WHERE ref_code = ?").bind(code).first();
  if (!ref || ref.id === newUser.id) return;
  const hs = await deviceHashes(request);
  let reason = null;
  if (hs.length) {
    const q = hs.map(() => "?").join(",");
    const own = await env.DB.prepare(`SELECT 1 FROM devices WHERE user_id = ? AND hash IN (${q}) LIMIT 1`).bind(ref.id, ...hs).first();
    // the same phone already made another account from this link
    const dup = await env.DB.prepare(`SELECT 1 FROM devices d JOIN referrals r ON r.referred_id = d.user_id WHERE r.referrer_id = ? AND d.hash IN (${q}) LIMIT 1`).bind(ref.id, ...hs).first();
    if (own || dup) reason = "same_device";
  }
  await env.DB.batch([
    env.DB.prepare("INSERT OR IGNORE INTO referrals (id, referrer_id, referred_id, referred_name, status, reason, created_at, decided_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
      .bind(crypto.randomUUID(), ref.id, newUser.id, newUser.name, reason ? "rejected" : "pending", reason, now(), reason ? now() : null),
    env.DB.prepare("UPDATE users SET referred_by = ? WHERE id = ?").bind(ref.id, newUser.id),
  ]);
  if (!reason) await postMessage(env, ref.id, null, "ref_signup", { name: newUser.name }, "ref_signup:" + newUser.id);
}
async function referralSummary(env, userId) {
  const rows = (await env.DB.prepare("SELECT status, COUNT(*) AS n FROM referrals WHERE referrer_id = ? GROUP BY status").bind(userId).all()).results;
  const c = Object.fromEntries(rows.map((r) => [r.status, r.n]));
  return { code: await refCode(env, userId), goal: REF_GOAL, reward_cents: REF_REWARD_CENTS, qualified: c.qualified || 0, pending: c.pending || 0, rejected: c.rejected || 0 };
}
// hourly: decide pending referrals, hand out rewards, tell people when a card was sent
async function checkReferrals(env) {
  const appUrl = (env.APP_URL || "https://honeybun.me").replace(/\/$/, "");
  const due = (await env.DB.prepare(
    `SELECT r.id, r.referrer_id, r.referred_id, r.referred_name, r.created_at, u.id AS uid, u.email_verified
     FROM referrals r LEFT JOIN users u ON u.id = r.referred_id WHERE r.status = 'pending' AND r.created_at <= ? LIMIT 200`
  ).bind(now() - REF_DAYS * 86400).all()).results;
  for (const r of due) {
    try {
      const decide = (status, reason) => env.DB.prepare("UPDATE referrals SET status = ?, reason = ?, decided_at = ? WHERE id = ? AND status = 'pending'").bind(status, reason, now(), r.id).run();
      const expired = now() - r.created_at > REF_EXPIRE_DAYS * 86400;
      if (!r.uid) { await decide("rejected", "left"); continue; }
      const [act, house, theirs, mine] = await env.DB.batch([
        env.DB.prepare("SELECT COUNT(DISTINCT date(created_at, 'unixepoch')) AS days, MAX(created_at) AS last FROM entries WHERE created_by = ?").bind(r.referred_id),
        env.DB.prepare("SELECT 1 FROM members a JOIN members b ON a.nest_id = b.nest_id WHERE a.user_id = ? AND b.user_id = ? LIMIT 1").bind(r.referrer_id, r.referred_id),
        env.DB.prepare("SELECT hash FROM devices WHERE user_id = ?").bind(r.referred_id),
        env.DB.prepare("SELECT hash FROM devices WHERE user_id = ?").bind(r.referrer_id),
      ]);
      if (house.results.length) { await decide("rejected", "same_household"); continue; }
      const mineSet = new Set(mine.results.map((d) => d.hash)), theirHashes = theirs.results.map((d) => d.hash);
      if (theirHashes.length && theirHashes.every((h) => mineSet.has(h))) { await decide("rejected", "same_device"); continue; }
      const a = act.results[0] || {};
      const ok = r.email_verified && a.days >= REF_ACTIVE_DAYS && a.last >= r.created_at + REF_DAYS * 86400;
      if (!ok) { if (expired) await decide("rejected", !r.email_verified ? "unverified" : "inactive"); continue; }
      await decide("qualified", null);
      const n = (await env.DB.prepare("SELECT COUNT(*) AS n FROM referrals WHERE referrer_id = ? AND status = 'qualified'").bind(r.referrer_id).first()).n;
      await postMessage(env, r.referrer_id, null, "ref_qualified", { name: r.referred_name, n: ((n - 1) % REF_GOAL) + 1, goal: REF_GOAL }, "ref_ok:" + r.referred_id);
      if (n % REF_GOAL === 0) {
        const k = n / REF_GOAL, rid = `reward:${r.referrer_id}:${k}`;
        const ins = await env.DB.prepare("INSERT OR IGNORE INTO rewards (id, user_id, amount_cents, referrals, status, created_at) VALUES (?, ?, ?, ?, 'pending', ?)")
          .bind(rid, r.referrer_id, REF_REWARD_CENTS, REF_GOAL, now()).run();
        if (ins.meta?.changes) {
          await postMessage(env, r.referrer_id, null, "reward_earned", { amount: REF_REWARD_CENTS, n: REF_GOAL }, "reward:" + k);
          const who = await env.DB.prepare("SELECT name, email FROM users WHERE id = ?").bind(r.referrer_id).first();
          if (env.RESEND_API_KEY && who) {
            const to = env.REWARDS_EMAIL || "help@honeybun.me";
            const text = `${who.name} (${who.email}) just reached ${n} qualified referrals and earned a $${REF_REWARD_CENTS / 100} gift card.\n\nReward id: ${rid}\n\nSend the card to ${who.email}, then mark it sent so Bun lets them know.\n\n${appUrl}`;
            try { await sendEmail(env, to, `🎁 Gift card earned: ${who.name}`, text, `<pre style="font:14px/1.5 sans-serif;white-space:pre-wrap">${escHtml(text)}</pre>`); }
            catch (e) { console.error("reward email failed", e.message); }
          }
        }
      }
    } catch (e) { console.error("referral check failed", r.id, e.message); }
  }
  // gift cards marked as sent (status = 'sent') -> Bun lets the person know once
  const sent = (await env.DB.prepare("SELECT id, user_id, amount_cents FROM rewards WHERE status = 'sent' AND notified = 0 LIMIT 100").all()).results;
  for (const w of sent) {
    await postMessage(env, w.user_id, null, "reward_sent", { amount: w.amount_cents }, "reward_sent:" + w.id);
    await env.DB.prepare("UPDATE rewards SET notified = 1, sent_at = COALESCE(sent_at, ?) WHERE id = ?").bind(now(), w.id).run();
  }
}

// ---------- carrots, streaks & levels ----------
const CARROTS = { entry: 10, bill: 15, payday: 15, settle: 20, save: 10, debt: 20, setup: 50, plan: 5 };
const DAILY_CAP = 200;
const levelFor = (xp) => { let l = 1; while (xp >= 25 * (l + 1) * l) l++; return l; }; // L2 at 50, L3 at 150, L4 at 300...
function localDay(request) {
  const d = request.headers.get("x-local-date") || "";
  const utc = Date.now();
  if (/^\d{4}-\d{2}-\d{2}$/.test(d) && Math.abs(Date.parse(d + "T12:00:00Z") - utc) < 2 * 86400000) return d;
  return new Date(utc).toISOString().slice(0, 10);
}
const dayBefore = (d) => new Date(Date.parse(d + "T12:00:00Z") - 86400000).toISOString().slice(0, 10);
function weekKey(d) { // Monday-based week
  const t = new Date(d + "T12:00:00Z"), dow = (t.getUTCDay() + 6) % 7;
  return new Date(t.getTime() - dow * 86400000).toISOString().slice(0, 10);
}
async function award(env, request, userId, nestId, action) {
  const m = await env.DB.prepare("SELECT xp, streak, best_streak, last_day, day_xp, week_key, week_xp, logs FROM members WHERE user_id = ? AND nest_id = ?").bind(userId, nestId).first();
  if (!m) return null;
  const day = localDay(request), wk = weekKey(day);
  const newDay = m.last_day !== day;
  const streak = !newDay ? m.streak : m.last_day === dayBefore(day) ? m.streak + 1 : 1;
  const dayXp = newDay ? 0 : m.day_xp;
  const gained = Math.max(0, Math.min(CARROTS[action] || 0, DAILY_CAP - dayXp));
  const xp = m.xp + gained, weekXp = (m.week_key === wk ? m.week_xp : 0) + gained;
  await env.DB.prepare("UPDATE members SET xp = ?, streak = ?, best_streak = ?, last_day = ?, day_xp = ?, week_key = ?, week_xp = ?, logs = ? WHERE user_id = ? AND nest_id = ?")
    .bind(xp, streak, Math.max(m.best_streak, streak), day, dayXp + gained, wk, weekXp, m.logs + (action === "entry" ? 1 : 0), userId, nestId).run();
  const leveled = levelFor(xp) > levelFor(m.xp);
  if (leveled) await postMessage(env, userId, nestId, "level", { level: levelFor(xp) }, `level:${levelFor(xp)}`);
  if (newDay && STREAK_MILESTONES.includes(streak)) await postMessage(env, userId, nestId, "streak_milestone", { n: streak }, `streak:${streak}:${day}`);
  return { gained, xp, level: levelFor(xp), leveled, streak, streak_up: newDay && streak > 1, first_today: newDay };
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
// ---------- usernames (accounts without an email) ----------
// A username account is stored as username@u.honeybun.invalid so every existing login rule keeps working.
// That address never receives mail; the person gets a recovery code to reset a forgotten password instead.
const USERNAME_DOMAIN = "u.honeybun.invalid";
const isUsername = (u) => /^[a-z0-9][a-z0-9._-]{2,19}$/.test(u);
const toLoginKey = (v) => { const x = String(v ?? "").trim().toLowerCase(); return x.includes("@") ? x : x + "@" + USERNAME_DOMAIN; };
const hasRealEmail = (e) => !String(e).endsWith("@" + USERNAME_DOMAIN);
function newRecoveryCode() {
  const A = "ABCDEFGHJKMNPQRSTUVWXYZ23456789", b = crypto.getRandomValues(new Uint8Array(12));
  const c = Array.from(b, (x) => A[x % A.length]).join("");
  return `${c.slice(0, 4)}-${c.slice(4, 8)}-${c.slice(8)}`;
}
const recoveryKey = (c) => String(c ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");

async function sendEmail(env, to, subject, text, html, headers) {
  if (!hasRealEmail(to)) return; // username accounts have no inbox
  if (!env.RESEND_API_KEY) throw new HttpError("Emails aren't set up yet. Ask the site owner to add the email key.", 503);
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { authorization: `Bearer ${env.RESEND_API_KEY}`, "content-type": "application/json" },
    body: JSON.stringify({ from: env.MAIL_FROM || "Honeybun <hello@honeybun.me>", to: [to], subject, text, html, ...(headers ? { headers } : {}) }),
  });
  if (!res.ok) { console.error("Resend error", res.status, await res.text()); throw new HttpError("Couldn't send the email. Try again in a minute.", 502); }
}

// ---------- email templates (English / Spanish / Chinese) ----------
const escHtml = (v) => String(v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const LANGS = ["en", "es", "zh"];
const MAIL = {
  en: {
    tagline: "Honeybun, a cute little budget", noBtn: "Button not working? Copy this link into your browser:", unsub: "Turn off these emails", open: "Open Honeybun",
    resetSubj: "Reset your Honeybun password 🐰", resetHead: "Forgot your password? No worries.", resetBody: (n) => `Hi ${n}, tap the button below to choose a new password for Honeybun.`,
    resetBtn: "Choose a new password", resetNote: (m) => `This link works for ${m} minutes and can only be used once. If you didn't ask for this, you can ignore this email. Your password won't change.`,
    verifySubj: "Confirm your Honeybun email 🐰", verifyHead: "One quick thing", verifyBody: (n) => `Hi ${n}, tap below to confirm this is your email. That way reminders and password resets reach the right place.`,
    verifyBtn: "Confirm my email", verifyNote: "This link works for 24 hours. If you didn't sign up for Honeybun, you can ignore this email.",
    billsSubj: (k) => `${k} bill${k === 1 ? "" : "s"} due soon 🐰`, billsHead: "Coming up this week", billsBody: (n) => `Hi ${n}, here's what's due in the next few days.`,
    streakSubj: (k) => `Don't lose your ${k}-day streak 🐾`, streakHead: "Your bunny misses you", streakBody: (n, k) => `Hi ${n}, log one thing today to keep your ${k}-day hop streak going.`, streakBtn: "Log something",
    weekSubj: "Your week in Honeybun 🥕", weekHead: "Your week", weekBody: (n) => `Hi ${n}, here's how your week went.`,
    spent: "Spent", top: "Top category", carrots: "Carrots earned", streak: "Hop streak", days: (k) => `${k} day${k === 1 ? "" : "s"}`, due: "due",
  },
  es: {
    tagline: "Honeybun, un presupuesto lindo", noBtn: "¿El botón no funciona? Copia este enlace en tu navegador:", unsub: "Desactivar estos correos", open: "Abrir Honeybun",
    resetSubj: "Restablece tu contraseña de Honeybun 🐰", resetHead: "¿Olvidaste tu contraseña? No pasa nada.", resetBody: (n) => `Hola ${n}, toca el botón para elegir una nueva contraseña de Honeybun.`,
    resetBtn: "Elegir nueva contraseña", resetNote: (m) => `Este enlace funciona durante ${m} minutos y solo se puede usar una vez. Si no lo pediste, ignora este correo. Tu contraseña no cambiará.`,
    verifySubj: "Confirma tu correo de Honeybun 🐰", verifyHead: "Una cosita más", verifyBody: (n) => `Hola ${n}, toca abajo para confirmar que este es tu correo. Así los recordatorios y restablecimientos llegan al lugar correcto.`,
    verifyBtn: "Confirmar mi correo", verifyNote: "Este enlace funciona durante 24 horas. Si no te registraste en Honeybun, ignora este correo.",
    billsSubj: (k) => `${k} ${k === 1 ? "factura vence" : "facturas vencen"} pronto 🐰`, billsHead: "Esta semana", billsBody: (n) => `Hola ${n}, esto vence en los próximos días.`,
    streakSubj: (k) => `No pierdas tu racha de ${k} días 🐾`, streakHead: "Tu conejito te extraña", streakBody: (n, k) => `Hola ${n}, registra algo hoy para mantener tu racha de ${k} días.`, streakBtn: "Registrar algo",
    weekSubj: "Tu semana en Honeybun 🥕", weekHead: "Tu semana", weekBody: (n) => `Hola ${n}, así fue tu semana.`,
    spent: "Gastado", top: "Categoría principal", carrots: "Zanahorias ganadas", streak: "Racha", days: (k) => `${k} ${k === 1 ? "día" : "días"}`, due: "vence",
  },
  zh: {
    tagline: "Honeybun，可爱的小预算", noBtn: "按钮无法使用？请将此链接复制到浏览器：", unsub: "关闭这些邮件", open: "打开 Honeybun",
    resetSubj: "重置你的 Honeybun 密码 🐰", resetHead: "忘记密码了？别担心。", resetBody: (n) => `${n}，你好！点击下方按钮，为 Honeybun 设置新密码。`,
    resetBtn: "设置新密码", resetNote: (m) => `此链接在 ${m} 分钟内有效，且只能使用一次。如果不是你本人操作，请忽略此邮件，你的密码不会改变。`,
    verifySubj: "确认你的 Honeybun 邮箱 🐰", verifyHead: "还差一小步", verifyBody: (n) => `${n}，你好！点击下方确认这是你的邮箱，这样提醒和重置密码邮件才能准确送达。`,
    verifyBtn: "确认我的邮箱", verifyNote: "此链接在 24 小时内有效。如果你没有注册 Honeybun，请忽略此邮件。",
    billsSubj: (k) => `${k} 笔账单即将到期 🐰`, billsHead: "本周待付", billsBody: (n) => `${n}，你好！以下账单将在几天内到期。`,
    streakSubj: (k) => `别让你的 ${k} 天连续记录中断 🐾`, streakHead: "你的小兔子想你了", streakBody: (n, k) => `${n}，你好！今天记一笔，保持你 ${k} 天的连续记录。`, streakBtn: "记一笔",
    weekSubj: "你的 Honeybun 一周 🥕", weekHead: "你的一周", weekBody: (n) => `${n}，你好！这是你本周的情况。`,
    spent: "支出", top: "最大类别", carrots: "获得胡萝卜", streak: "连续记录", days: (k) => `${k} 天`, due: "到期",
  },
};
const mailT = (lang) => MAIL[LANGS.includes(lang) ? lang : "en"];
const money = (c) => "$" + (c / 100).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
function mailHtml({ lang, heading, intro, rows = "", button, link, note = "", appUrl, unsubUrl }) {
  const t = mailT(lang), home = escHtml(appUrl), url = link ? escHtml(link) : "";
  return `<!DOCTYPE html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light only"></head>
<body style="margin:0;padding:0;background:#F3F5FA;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F3F5FA;"><tr><td align="center" style="padding:40px 16px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:440px;">
<tr><td align="center" style="padding-bottom:20px;"><img src="${home}/icon-192.png" width="64" height="64" alt="Honeybun" style="display:block;border-radius:18px;border:0;"></td></tr>
<tr><td style="background:#FFFFFF;border-radius:24px;padding:32px 28px;font-family:'Segoe UI',Helvetica,Arial,sans-serif;color:#2B2733;">
<h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;font-weight:700;">${escHtml(heading)}</h1>
<p style="margin:0 0 20px;font-size:16px;line-height:1.6;color:#4A4453;">${escHtml(intro)}</p>
${rows}
${button ? `<table role="presentation" cellpadding="0" cellspacing="0" width="100%"><tr><td align="center" style="padding-top:6px;"><a href="${url}" style="display:inline-block;background:#6F93DB;color:#FFFFFF;text-decoration:none;font-weight:700;font-size:16px;padding:14px 28px;border-radius:14px;">${escHtml(button)}</a></td></tr></table>` : ""}
${note ? `<p style="margin:22px 0 0;font-size:14px;line-height:1.6;color:#8E8898;">${escHtml(note)}</p>` : ""}
${link && note ? `<hr style="border:0;border-top:1px solid #EAE7EF;margin:22px 0;"><p style="margin:0;font-size:12px;line-height:1.6;color:#A7A1B0;word-break:break-all;">${escHtml(t.noBtn)}<br><a href="${url}" style="color:#6F93DB;">${url}</a></p>` : ""}
</td></tr>
<tr><td align="center" style="padding:20px 0 0;font-family:'Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;color:#A7A1B0;line-height:1.7;">${escHtml(t.tagline)}<br><a href="${home}" style="color:#A7A1B0;">honeybun.me</a>${unsubUrl ? ` · <a href="${escHtml(unsubUrl)}" style="color:#A7A1B0;">${escHtml(t.unsub)}</a>` : ""}</td></tr>
</table></td></tr></table></body></html>`;
}
const mailRows = (pairs) => `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 20px;">${pairs.map(([a, b]) =>
  `<tr><td style="padding:10px 0;border-bottom:1px solid #EAE7EF;font-size:15px;color:#2B2733;">${escHtml(a)}</td><td align="right" style="padding:10px 0;border-bottom:1px solid #EAE7EF;font-size:15px;font-weight:700;color:#2B2733;">${escHtml(b)}</td></tr>`).join("")}</table>`;
function resetEmail(name, link, appUrl, lang) {
  const t = mailT(lang);
  return { subject: t.resetSubj,
    text: `${t.resetBody(name)}\n\n${link}\n\n${t.resetNote(RESET_MINUTES)}`,
    html: mailHtml({ lang, heading: t.resetHead, intro: t.resetBody(name), button: t.resetBtn, link, note: t.resetNote(RESET_MINUTES), appUrl }) };
}
async function sendVerify(env, user, appUrl) {
  const token = randomToken(), t = mailT(user.lang);
  await env.DB.batch([
    env.DB.prepare("DELETE FROM verify_tokens WHERE user_id = ?").bind(user.id),
    env.DB.prepare("INSERT INTO verify_tokens (token_hash, user_id, expires_at) VALUES (?, ?, ?)").bind(await sha256(token), user.id, now() + 86400),
  ]);
  const link = `${appUrl}/verify/${token}`;
  await sendEmail(env, user.email, t.verifySubj, `${t.verifyBody(user.name)}\n\n${link}\n\n${t.verifyNote}`,
    mailHtml({ lang: user.lang, heading: t.verifyHead, intro: t.verifyBody(user.name), button: t.verifyBtn, link, note: t.verifyNote, appUrl }));
}

// ---------- bills & local time helpers (for reminders) ----------
const dayMs = 86400000;
const pDay = (s) => { const [y, m, d] = s.split("-").map(Number); return Date.UTC(y, m - 1, d); };
const sDay = (t) => new Date(t).toISOString().slice(0, 10);
function occurrencesS(r, fromStr, toStr) {
  const a = pDay(r.anchor_date), from = pDay(fromStr), to = pDay(toStr), out = [];
  if (r.freq === "monthly") {
    const day = new Date(a).getUTCDate();
    let y = new Date(from).getUTCFullYear(), m = new Date(from).getUTCMonth();
    for (let i = 0; i < 26; i++) {
      const t = Date.UTC(y, m, Math.min(day, new Date(Date.UTC(y, m + 1, 0)).getUTCDate()));
      if (t > to) break;
      if (t >= from && t >= a) out.push(sDay(t));
      if (++m > 11) { m = 0; y++; }
    }
  } else {
    const step = (r.freq === "weekly" ? 7 : 14) * dayMs;
    let t = a;
    if (t < from) t = a + Math.ceil((from - a) / step) * step;
    for (let i = 0; t <= to && i < 60; i++) { out.push(sDay(t)); t += step; }
  }
  return out;
}
function localNow(tz) {
  try {
    const f = new Intl.DateTimeFormat("en-CA", { timeZone: tz || "America/New_York", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23", weekday: "short" });
    const p = Object.fromEntries(f.formatToParts(new Date()).map((x) => [x.type, x.value]));
    return { date: `${p.year}-${p.month}-${p.day}`, hour: Number(p.hour) % 24, weekday: p.weekday };
  } catch { return tz ? localNow(null) : { date: todayStr(), hour: new Date().getUTCHours(), weekday: "" }; }
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
// ---------- carry over: a month's leftover (or shortfall) moves into the next month ----------
const prevMonth = (ym) => { const [y, m] = ym.split("-").map(Number); return m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, "0")}`; };
// what the household ended a month with: income minus spending (private entries stay private), plus what came in from the month before
const isJoint = async (env, nestId) => !!(await env.DB.prepare("SELECT joint FROM nests WHERE id = ?").bind(nestId).first())?.joint;
async function monthBalance(env, nestId, ym) {
  const r = await env.DB.prepare(
    "SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount_cents ELSE -amount_cents END), 0) AS b, COUNT(*) AS n FROM entries WHERE nest_id = ? AND substr(date, 1, 7) = ? AND private = 0"
  ).bind(nestId, ym).first();
  const c = await env.DB.prepare("SELECT amount_cents FROM month_carry WHERE nest_id = ? AND month = ?").bind(nestId, ym).first();
  return { cents: r.b + (c ? c.amount_cents : 0), entries: r.n, carried: c ? c.amount_cents : 0 };
}
const MAX_CUSTOM = 12;
async function customCategoryIds(env, nestId) {
  return new Set((await env.DB.prepare("SELECT id FROM custom_categories WHERE nest_id = ?").bind(nestId).all()).results.map((r) => r.id));
}
const isCustomId = (c) => typeof c === "string" && /^c_[0-9a-f]{12}$/.test(c);

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
  const priv = !shared && !!body.private && memberId === user.id && !(await isJoint(env, nestId)) ? 1 : 0;
  return {
    type, amount, memberId, shared: shared ? 1 : 0, split, shares, priv,
    category: type === "expense" ? (CATEGORIES.includes(body.category) || (isCustomId(body.category) && (await customCategoryIds(env, nestId)).has(body.category)) ? body.category : "other") : null,
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

// Your most common expenses over the last 90 days (label + category), newest amount wins.
// Used for one-tap repeats on the Add screen and to auto-fill Shortcut logs.
async function topRepeats(env, nestId, userId, limit = 5) {
  const since = sDay(Date.now() - 90 * dayMs);
  const rows = (await env.DB.prepare(
    `SELECT label, category, amount_cents, shared, split_mode, split_value, private, date FROM entries
     WHERE nest_id = ? AND member_id = ? AND type = 'expense' AND recurring_id IS NULL AND date >= ? ORDER BY date DESC, created_at DESC LIMIT 400`
  ).bind(nestId, userId, since).all()).results;
  const groups = new Map();
  for (const r of rows) {
    const key = r.label.toLowerCase() + "|" + (r.category || "other");
    const g = groups.get(key);
    if (g) { g.count++; g.amounts.push(r.amount_cents); }
    else groups.set(key, { ...r, count: 1, amounts: [r.amount_cents] });
  }
  return [...groups.values()]
    .filter((g) => g.count >= 2 || rows.length < 8) // brand-new budgets get suggestions right away
    .sort((a, b) => b.count - a.count || (b.date < a.date ? -1 : 1))
    .slice(0, limit)
    .map((g) => ({ label: g.label, category: g.category, amount_cents: g.amount_cents, shared: g.shared, split_mode: g.split_mode, split_value: g.split_value, private: g.private, count: g.count }));
}

// Budget rollover: unspent budget carries into the next month (chained, up to 12 months back).
// Returns { category: carry_cents } for the given month, or {} when rollover is off.
async function budgetCarry(env, nestId, userId, month) {
  const nest = await env.DB.prepare("SELECT rollover, rollover_since FROM nests WHERE id = ?").bind(nestId).first();
  if (!nest || !nest.rollover) return {};
  const since = nest.rollover_since || month;
  const budgets = (await env.DB.prepare("SELECT category, limit_cents FROM budgets WHERE nest_id = ?").bind(nestId).all()).results;
  if (!budgets.length) return {};
  const [y, m] = month.split("-").map(Number);
  const months = [];
  for (let i = 12; i >= 1; i--) { const d = new Date(Date.UTC(y, m - 1 - i, 1)).toISOString().slice(0, 7); if (d >= since) months.push(d); }
  if (!months.length) return {};
  const spent = (await env.DB.prepare(
    "SELECT substr(date, 1, 7) AS ym, category, SUM(amount_cents) AS c FROM entries WHERE nest_id = ? AND type = 'expense' AND date >= ? AND date < ? AND (private = 0 OR member_id = ?) GROUP BY ym, category"
  ).bind(nestId, months[0] + "-01", month + "-01", userId).all()).results;
  const by = {}; for (const r of spent) by[r.ym + "|" + r.category] = r.c;
  const carry = {};
  for (const b of budgets) {
    let c = 0;
    for (const ym of months) c = Math.max(0, b.limit_cents + c - (by[ym + "|" + b.category] || 0));
    carry[b.category] = c;
  }
  return carry;
}

// ---------- Sign in with Apple ----------
const APPLE_ISS = "https://appleid.apple.com";
let appleKeysCache = null, appleKeysAt = 0;
const sha256hex = async (text) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(text)))).map((b) => b.toString(16).padStart(2, "0")).join("");
async function appleKeys(env, force) {
  if (env.APPLE_TEST_JWKS) return JSON.parse(env.APPLE_TEST_JWKS).keys; // tests only: never set in production
  if (!force && appleKeysCache && Date.now() - appleKeysAt < 3600_000) return appleKeysCache;
  const res = await fetch(env.APPLE_JWKS_URL || (APPLE_ISS + "/auth/keys"));
  if (!res.ok) throw new HttpError("Apple sign-in is unavailable right now. Try again.", 503);
  appleKeysCache = (await res.json()).keys || []; appleKeysAt = Date.now();
  return appleKeysCache;
}
async function verifyAppleToken(env, token, rawNonce) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new HttpError("Apple sign-in failed. Try again.", 401);
  const header = JSON.parse(new TextDecoder().decode(fromB64u(parts[0]))), claims = JSON.parse(new TextDecoder().decode(fromB64u(parts[1])));
  if (header.alg !== "RS256") throw new HttpError("Apple sign-in failed. Try again.", 401);
  let jwk = (await appleKeys(env, false)).find((k) => k.kid === header.kid);
  if (!jwk) jwk = (await appleKeys(env, true)).find((k) => k.kid === header.kid); // Apple rotated its keys
  if (!jwk) throw new HttpError("Apple sign-in failed. Try again.", 401);
  const key = await crypto.subtle.importKey("jwk", { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true }, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const good = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, fromB64u(parts[2]), enc.encode(parts[0] + "." + parts[1]));
  const audOk = Array.isArray(claims.aud) ? claims.aud.includes(env.APPLE_CLIENT_ID) : claims.aud === env.APPLE_CLIENT_ID;
  if (!good || claims.iss !== APPLE_ISS || !audOk || !claims.sub || Number(claims.exp) < now() || Number(claims.iat) > now() + 300
      || !claims.nonce || claims.nonce !== (await sha256hex(rawNonce)))
    throw new HttpError("Apple sign-in failed. Try again.", 401);
  return claims;
}
// revoke the Sign in with Apple link when an account is deleted (needs the Apple key: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY)
async function revokeApple(env, authorizationCode) {
  if (!env.APPLE_TEAM_ID || !env.APPLE_KEY_ID || !env.APPLE_PRIVATE_KEY || !env.APPLE_CLIENT_ID) return;
  const pem = String(env.APPLE_PRIVATE_KEY).replace(/-----[A-Z ]+-----/g, "").replace(/\\n|\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const head = b64u(enc.encode(JSON.stringify({ alg: "ES256", kid: env.APPLE_KEY_ID }))), iat = now();
  const body = b64u(enc.encode(JSON.stringify({ iss: env.APPLE_TEAM_ID, iat, exp: iat + 300, aud: APPLE_ISS, sub: env.APPLE_CLIENT_ID })));
  const secret = head + "." + body + "." + b64u(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(head + "." + body)));
  const form = (o) => new URLSearchParams(o).toString(), hdr = { "content-type": "application/x-www-form-urlencoded" };
  const tok = await (await fetch(APPLE_ISS + "/auth/token", { method: "POST", headers: hdr, body: form({ client_id: env.APPLE_CLIENT_ID, client_secret: secret, code: authorizationCode, grant_type: "authorization_code" }) })).json();
  const t = tok.refresh_token || tok.access_token;
  if (t) await fetch(APPLE_ISS + "/auth/revoke", { method: "POST", headers: hdr, body: form({ client_id: env.APPLE_CLIENT_ID, client_secret: secret, token: t, token_type_hint: tok.refresh_token ? "refresh_token" : "access_token" }) });
}

// ---------- passkeys (WebAuthn, no library) ----------
const derToRaw = (der) => { // ECDSA DER signature -> raw r||s (64 bytes)
  const b = new Uint8Array(der); let i = 2; const out = new Uint8Array(64);
  for (let k = 0; k < 2; k++) { if (b[i++] !== 2) throw new HttpError("Bad signature."); let len = b[i++], start = i; while (len > 32) { start++; len--; } out.set(b.slice(start, start + len), k * 32 + (32 - len)); i = start + len; }
  return out;
};
async function verifyWebauthn(key, alg, authData, clientDataJSON, signature) {
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", clientDataJSON));
  const data = new Uint8Array(authData.length + 32); data.set(authData); data.set(hash, authData.length);
  if (alg === -7) {
    const k = await crypto.subtle.importKey("spki", key, { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
    return crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, k, derToRaw(signature), data);
  }
  if (alg === -257) {
    const k = await crypto.subtle.importKey("spki", key, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
    return crypto.subtle.verify("RSASSA-PKCS1-v1_5", k, signature, data);
  }
  return false;
}
async function takeChallenge(env, id, kind) {
  const row = await env.DB.prepare("SELECT user_id, expires_at FROM challenges WHERE id = ? AND kind = ?").bind(id, kind).first();
  await env.DB.prepare("DELETE FROM challenges WHERE id = ?").bind(id).run();
  if (!row || row.expires_at < now()) throw new HttpError("That took too long. Try again.", 400);
  return row;
}
// wrangler dev rewrites Host/Origin to the production host, so local testing needs DEV_ORIGIN in .dev.vars
const rpOrigin = (env, url) => (env.DEV_ORIGIN ? new URL(env.DEV_ORIGIN) : url);
async function checkClientData(env, raw, type, kind, url) {
  let cd; try { cd = JSON.parse(new TextDecoder().decode(raw)); } catch { throw new HttpError("Bad passkey data."); }
  if (cd.type !== type) throw new HttpError("Bad passkey data.");
  if (cd.origin !== rpOrigin(env, url).origin) throw new HttpError("This passkey was made for a different site.");
  return takeChallenge(env, String(cd.challenge || ""), kind);
}
async function checkAuthData(env, authData, url, needUserPresent) {
  const rpHash = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(rpOrigin(env, url).hostname)));
  for (let i = 0; i < 32; i++) if (authData[i] !== rpHash[i]) throw new HttpError("This passkey was made for a different site.");
  if (needUserPresent && !(authData[32] & 1)) throw new HttpError("Passkey check failed.");
  const dv = new DataView(authData.buffer, authData.byteOffset);
  return dv.getUint32(33);
}

// Guess a category for a store name coming from Apple Pay (only used when the Shortcut doesn't send one)
const STORE_HINTS = [
  ["groc", /costco|walmart|target|kroger|safeway|aldi|trader|whole foods|publix|heb|h-e-b|wegmans|market|grocer|supermarket|food lion|meijer|winco|sprouts|sam's/i],
  ["food", /starbucks|dunkin|coffee|cafe|caf\u00e9|mcdonald|chick|taco|pizza|burger|wendy|chipotle|subway|panera|doordash|uber ?eats|grubhub|restaurant|grill|kitchen|sushi|ramen|bbq|diner|bakery|donut|boba|\btea\b/i],
  ["car", /shell|chevron|exxon|mobil|bp\b|arco|76\b|\bgas\b|fuel|texaco|valero|circle k|wawa|sheetz|autozone|jiffy|car wash|parking|toll|uber(?! ?eats)|lyft/i],
  ["subs", /netflix|spotify|hulu|disney|apple\.com|icloud|youtube|amazon prime|hbo|\bmax\b|paramount|peacock|audible|patreon|openai|adobe|google (one|storage)|xbox|playstation|nintendo/i],
  ["bills", /electric|power|water|utility|utilities|internet|comcast|xfinity|spectrum|verizon|at&t|t-mobile|insurance|rent|mortgage/i],
  ["home", /home depot|lowe'?s|ikea|wayfair|bed bath|container store|ace hardware/i],
  ["fun", /amc|cinema|theat|regal|steam|ticketmaster|bowling|arcade|museum|zoo|concert|eventbrite|topgolf/i],
  ["pets", /petco|petsmart|chewy|vet\b|veterinar|pet /i],
  ["date", /date night|florist|flowers/i],
];
const guessCategory = (label) => (STORE_HINTS.find(([, re]) => re.test(label)) || ["other"])[0];

async function keyUser(request, env) {
  const m = /^Bearer\s+([A-Za-z0-9_-]{20,})$/.exec(request.headers.get("authorization") || "");
  if (!m) return null;
  const row = await env.DB.prepare(
    "SELECT u.id, u.email, u.name, u.lang, k.token_hash FROM api_keys k JOIN users u ON u.id = k.user_id WHERE k.token_hash = ?"
  ).bind(await sha256(m[1])).first();
  if (row) return row;
  // the iPhone app's own token (used by the widget and Siri shortcuts)
  return (await env.DB.prepare(
    "SELECT u.id, u.email, u.name, u.lang, a.token_hash FROM app_tokens a JOIN users u ON u.id = a.user_id WHERE a.token_hash = ?"
  ).bind(await sha256(m[1])).first()) || null;
}

// ---------- routes ----------
async function handle(request, env, url) {
  const path = url.pathname, method = request.method;
  const ip = request.headers.get("cf-connecting-ip") || "unknown";
  const appUrl = (env.APP_URL || url.origin).replace(/\/$/, "");

  let body = {};
  if (path === "/api/log" && method === "POST" && !(request.headers.get("content-type") || "").includes("json")) {
    body = Object.fromEntries((await request.formData().catch(() => new FormData())).entries());
  } else if (method === "POST" || method === "PATCH" || method === "PUT") {
    const raw = await request.text().catch(() => "");
    body = raw.trim() ? (() => { try { return JSON.parse(raw); } catch { return null; } })() : {};
    if (!body || typeof body !== "object") throw new HttpError("Invalid request.");
  }

  // ===== public =====
  if (path === "/api/signup" && method === "POST") {
    if (await limited(env, "signup:" + ip, 10, 3600)) throw new HttpError("Too many sign-ups from here. Try again in an hour.", 429);
    const name = cleanText(body.name, 24);
    const username = body.username ? String(body.username).trim().toLowerCase() : "";
    const email = username ? username + "@" + USERNAME_DOMAIN : cleanText(body.email, 254).toLowerCase();
    if (!name) throw new HttpError("Enter your name.");
    if (username) { if (!isUsername(username)) throw new HttpError("Usernames are 3 to 20 letters, numbers, dots, dashes or underscores."); }
    else if (!isEmail(email)) throw new HttpError("Enter a valid email address.");
    // a passkey-only account has no password to type: it gets a long random one nobody knows
    const password = body.passkey ? randomToken() : checkPassword(body.password);
    await recordAttempt(env, "signup:" + ip);
    if (await env.DB.prepare("SELECT 1 FROM users WHERE email = ?").bind(email).first())
      throw new HttpError(username ? "That username is taken. Try another one." : "An account with that email already exists. Log in instead.", 409);
    const id = crypto.randomUUID(), lang = LANGS.includes(body.lang) ? body.lang : "en";
    const code = username ? newRecoveryCode() : null;
    await env.DB.prepare("INSERT INTO users (id, email, name, pw, lang, created_at, recovery_hash, pw_known) VALUES (?, ?, ?, ?, ?, ?, ?, ?)").bind(id, email, name, await hashPassword(password), lang, now(), code ? await sha256(recoveryKey(code)) : null, body.passkey ? 0 : 1).run();
    try { if (body.ref) await recordReferral(env, request, { id, name }, body.ref); await rememberDevices(env, request, id); } catch (e) { console.error("referral failed", e.message); }
    if (!username) { try { await sendVerify(env, { id, email, name, lang }, appUrl); } catch (e) { console.error("verify email failed", e.message); } }
    return json({ ok: true, ...(code ? { recovery_code: code } : {}) }, 201, { "set-cookie": await createSession(env, id) });
  }

  if (path === "/api/login" && method === "POST") {
    const email = toLoginKey(cleanText(body.email, 254)), password = String(body.password ?? "");
    if ((await limited(env, "login:" + email, 10, 900)) || (await limited(env, "loginip:" + ip, 40, 900)))
      throw new HttpError("Too many tries. Wait 15 minutes and try again.", 429);
    const user = await env.DB.prepare("SELECT id, pw FROM users WHERE email = ?").bind(email).first();
    const ok = await verifyPassword(password, user ? user.pw : DUMMY_HASH);
    if (!user || !ok) {
      await recordAttempt(env, "login:" + email); await recordAttempt(env, "loginip:" + ip);
      throw new HttpError("Wrong email, username or password.", 401);
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
    const user = await env.DB.prepare("SELECT id, name, lang FROM users WHERE email = ?").bind(email).first();
    if (user) {
      const token = randomToken();
      await env.DB.batch([
        env.DB.prepare("DELETE FROM password_resets WHERE user_id = ?").bind(user.id),
        env.DB.prepare("INSERT INTO password_resets (token_hash, user_id, expires_at) VALUES (?, ?, ?)").bind(await sha256(token), user.id, now() + RESET_MINUTES * 60),
      ]);
      const link = `${appUrl}/reset/${token}`;
      const mail = resetEmail(user.name, link, appUrl, user.lang);
      await sendEmail(env, email, mail.subject, mail.text, mail.html);
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

  if (path === "/api/email/verify" && method === "POST") {
    if (await limited(env, "verifyip:" + ip, 30, 3600)) throw new HttpError("Too many tries. Try again later.", 429);
    await recordAttempt(env, "verifyip:" + ip);
    const row = await env.DB.prepare("SELECT user_id FROM verify_tokens WHERE token_hash = ? AND expires_at > ?").bind(await sha256(String(body.token ?? "")), now()).first();
    if (!row) throw new HttpError("This link has expired or was already used. You can send a new one from Settings.", 400);
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET email_verified = 1 WHERE id = ?").bind(row.user_id),
      env.DB.prepare("DELETE FROM verify_tokens WHERE user_id = ?").bind(row.user_id),
    ]);
    return json({ ok: true });
  }

  if (path === "/api/unsubscribe" && method === "GET") {
    const u = url.searchParams.get("u") || "", t = url.searchParams.get("t") || "", k = url.searchParams.get("k") || "";
    const col = { bills: "mail_bills", streak: "mail_streak", weekly: "mail_weekly" }[k];
    const row = await env.DB.prepare("SELECT unsub_token FROM users WHERE id = ?").bind(u).first();
    let ok = false;
    if (col && row && row.unsub_token && t.length > 20 && row.unsub_token === t) {
      await env.DB.prepare(`UPDATE users SET ${col} = 0 WHERE id = ?`).bind(u).run(); ok = true;
    }
    return new Response(`<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Honeybun</title></head>
      <body style="font-family:system-ui,sans-serif;background:#F3F5FA;color:#2B2733;display:grid;place-items:center;min-height:90vh;margin:0;padding:20px;text-align:center">
      <div><img src="/icon-192.png" width="64" height="64" alt="" style="border-radius:18px"><h1 style="font-size:1.3rem">${ok ? "You're unsubscribed" : "That link didn't work"}</h1>
      <p style="color:#8E8898">${ok ? "You won't get these emails anymore. You can turn them back on in Honeybun settings." : "You can turn emails off in Honeybun settings instead."}</p>
      <p><a href="/" style="color:#6F93DB;font-weight:700">Open Honeybun</a></p></div></body></html>`,
      { status: ok ? 200 : 400, headers: { "content-type": "text/html; charset=utf-8", ...SEC_HEADERS } });
  }

  // ===== passkey login (public) =====
  if (path === "/api/passkeys/login/options" && method === "POST") {
    if (await limited(env, "pklogin:" + ip, 60, 900)) throw new HttpError("Too many tries. Wait 15 minutes.", 429);
    const challenge = randomToken();
    await env.DB.prepare("INSERT INTO challenges (id, user_id, kind, expires_at) VALUES (?, NULL, 'login', ?)").bind(challenge, now() + 300).run();
    return json({ challenge, rpId: rpOrigin(env, url).hostname, timeout: 120000, userVerification: "preferred" });
  }
  if (path === "/api/passkeys/login" && method === "POST") {
    if (await limited(env, "pklogin:" + ip, 60, 900)) throw new HttpError("Too many tries. Wait 15 minutes.", 429);
    await recordAttempt(env, "pklogin:" + ip);
    const id = cleanText(body.id, 1024);
    const pk = await env.DB.prepare("SELECT id, user_id, public_key, alg, counter FROM passkeys WHERE id = ?").bind(id).first();
    if (!pk) throw new HttpError("That passkey isn't registered here. Log in with your password and add it in Settings.", 404);
    const clientData = fromB64u(String(body.clientDataJSON || "")), authData = fromB64u(String(body.authenticatorData || "")), sig = fromB64u(String(body.signature || ""));
    await checkClientData(env, clientData, "webauthn.get", "login", url);
    const counter = await checkAuthData(env, authData, url, true);
    if (!(await verifyWebauthn(fromB64u(pk.public_key), pk.alg, authData, clientData, sig))) throw new HttpError("Passkey check failed.", 401);
    if (counter && pk.counter && counter <= pk.counter) throw new HttpError("Passkey check failed.", 401);
    await env.DB.prepare("UPDATE passkeys SET counter = ?, last_used = ? WHERE id = ?").bind(counter, now(), pk.id).run();
    return json({ ok: true }, 200, { "set-cookie": await createSession(env, pk.user_id) });
  }
  if (path === "/api/push/key" && method === "GET") return json({ key: env.VAPID_PUBLIC_KEY || null });

  // ===== Shortcuts / Apple Pay auto-logging (Bearer key instead of a cookie) =====
  if (path === "/api/log" && method === "POST") {
    if (await limited(env, "logip:" + ip, 120, 3600)) throw new HttpError("Too many logs from here. Try again in an hour.", 429);
    const ku = await keyUser(request, env);
    if (!ku) { await recordAttempt(env, "logip:" + ip); throw new HttpError("That Shortcut key isn't valid. Make a new one in Honeybun settings.", 401); }
    const nestId = await requireNest(env, ku);
    // Apple Pay hands Shortcuts the amount as text like "$84.00" or "84,00", so tidy it up first
    const rawAmt = String(body.amount ?? body.total ?? "").replace(/[^0-9.,-]/g, "").replace(/,(?=\d{1,2}$)/, ".").replace(/,/g, "").replace(/-/g, "");
    const amount = toCents(rawAmt);
    const label = cleanText(body.store ?? body.label ?? body.merchant ?? body.name, 40) || "Apple Pay";
    const ids = await memberIds(env, nestId);
    // reuse how you logged this store last time (category + split), otherwise guess from the name
    const prev = await env.DB.prepare(
      "SELECT category, shared, split_mode, split_value, private FROM entries WHERE nest_id = ? AND member_id = ? AND type = 'expense' AND lower(label) = lower(?) ORDER BY date DESC, created_at DESC LIMIT 1"
    ).bind(nestId, ku.id, label).first();
    const category = CATEGORIES.includes(body.category) || (isCustomId(body.category) && (await customCategoryIds(env, nestId)).has(body.category)) ? body.category : prev ? prev.category || "other" : guessCategory(label);
    const shared = ids.length > 1 && (body.shared !== undefined ? !!body.shared && body.shared !== "false" && body.shared !== "no" : prev ? !!prev.shared : true);
    let split = { mode: null, value: null }, shares = null;
    if (shared) {
      split = prev && prev.shared && SPLITS.includes(prev.split_mode) ? { mode: prev.split_mode, value: prev.split_value } : { mode: "equal", value: null };
      if (split.mode === "owed" && split.value > amount) split = { mode: "equal", value: null };
      shares = JSON.stringify(computeShares(amount, split.mode, split.value, ku.id, ids));
    }
    const priv = !shared && !(await isJoint(env, nestId)) && (body.private !== undefined ? !!body.private && body.private !== "false" : !!prev?.private) ? 1 : 0;
    const u = await env.DB.prepare("SELECT tz FROM users WHERE id = ?").bind(ku.id).first();
    const date = isDate(body.date) ? body.date : localNow(u?.tz).date;
    const e = { type: "expense", amount, memberId: ku.id, shared: shared ? 1 : 0, split, shares, priv, category, label, date };
    const id = await insertEntry(env, nestId, ku, e);
    await env.DB.batch([
      env.DB.prepare("UPDATE api_keys SET last_used = ?, uses = uses + 1 WHERE token_hash = ?").bind(now(), ku.token_hash),
      env.DB.prepare("UPDATE members SET inbox_gen_at = 0 WHERE nest_id = ?").bind(nestId),
    ]);
    if (shared) await postToOthers(env, nestId, ku.id, "shared_expense", { name: ku.name, label, amount }, `shared:${id}`);
    let reward = null;
    try { reward = await award(env, { headers: new Headers({ "x-local-date": date }) }, ku.id, nestId, "entry"); } catch (err) { console.error("award", err.message); }
    const catName = { home: "Housing", groc: "Groceries", food: "Eating out", date: "Date night", bills: "Bills", subs: "Subscriptions", car: "Car", fun: "Fun", pets: "Pets", debt: "Debt", other: "Other" }[category] || "Other";
    return json({ ok: true, id, amount: amount / 100, label, category, shared, date,
      message: `Logged ${money(amount)} at ${label} (${catName}${shared ? ", split" : ""}) 🐰` }, 201);
  }

  // The iPhone widget asks for this with its own token: what's left this month and the next bill.
  if (path === "/api/app/summary" && method === "GET") {
    const ku = await keyUser(request, env);
    if (!ku) throw new HttpError("Not signed in.", 401);
    const nestId = await requireNest(env, ku);
    const u = await env.DB.prepare("SELECT tz FROM users WHERE id = ?").bind(ku.id).first();
    const L = localNow(u?.tz), ym = L.date.slice(0, 7);
    const t = await env.DB.prepare(
      "SELECT type, SUM(amount_cents) AS c FROM entries WHERE nest_id = ? AND substr(date, 1, 7) = ? AND (private = 0 OR member_id = ?) GROUP BY type"
    ).bind(nestId, ym, ku.id).all();
    const sum = Object.fromEntries(t.results.map((r) => [r.type, r.c]));
    const nest = await env.DB.prepare("SELECT name, kind FROM nests WHERE id = ?").bind(nestId).first();
    let next = null;
    try {
      const due = (await nestBillsDue(env, {}, nestId, L.date, sDay(pDay(L.date) + 14 * dayMs))).filter((x) => x.r.shared || x.r.member_id === ku.id);
      if (due.length) next = { label: due[0].r.label, amount: due[0].r.amount_cents / 100, date: due[0].d };
    } catch (e) { console.error("summary bills", e.message); }
    return json({ month: ym, name: nest?.name || "Honeybun", kind: nest?.kind || "couple", income: (sum.income || 0) / 100, spent: (sum.expense || 0) / 100, left: ((sum.income || 0) - (sum.expense || 0)) / 100, next });
  }

  if (path === "/api/auth/config" && method === "GET") return json({ apple: !!env.APPLE_CLIENT_ID });

  // Forgot your password and you have no email? The recovery code from sign-up sets a new one (and gives you a fresh code).
  if (path === "/api/password/recover" && method === "POST") {
    const key = toLoginKey(cleanText(body.username, 254));
    if ((await limited(env, "recover:" + key, 6, 3600)) || (await limited(env, "recoverip:" + ip, 20, 3600)))
      throw new HttpError("Too many tries. Wait an hour and try again.", 429);
    await recordAttempt(env, "recover:" + key); await recordAttempt(env, "recoverip:" + ip);
    const password = checkPassword(body.password);
    const u = await env.DB.prepare("SELECT id, recovery_hash FROM users WHERE email = ?").bind(key).first();
    if (!u || !u.recovery_hash || u.recovery_hash !== (await sha256(recoveryKey(body.code))))
      throw new HttpError("That username and recovery code don't match.", 401);
    const code = newRecoveryCode();
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET pw = ?, recovery_hash = ? WHERE id = ?").bind(await hashPassword(password), await sha256(recoveryKey(code)), u.id),
      env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(u.id),
    ]);
    return json({ ok: true, recovery_code: code }, 200, { "set-cookie": await createSession(env, u.id) });
  }

  // Sign in with Apple (the iPhone app): the app hands us Apple's signed identity token plus the secret it hashed into the request's nonce.
  // We verify Apple's signature, audience, expiry and nonce ourselves, then start the very same __Host-hb session as every other login.
  if (path === "/api/auth/apple" && method === "POST") {
    if (!env.APPLE_CLIENT_ID) throw new HttpError("Apple sign-in isn't set up yet.", 503);
    if (await limited(env, "apple:" + ip, 30, 3600)) throw new HttpError("Too many tries. Try again in an hour.", 429);
    await recordAttempt(env, "apple:" + ip);
    const token = String(body.identity_token || ""), nonce = String(body.nonce || "");
    if (token.length < 100 || token.length > 4000 || nonce.length < 8 || nonce.length > 200) throw new HttpError("Apple sign-in failed. Try again.", 400);
    let claims;
    try { claims = await verifyAppleToken(env, token, nonce); }
    catch (e) { if (e instanceof HttpError) throw e; throw new HttpError("Apple sign-in failed. Try again.", 401); }
    const claimed = String(claims.email || "").toLowerCase();
    // only a real, Apple-verified address that is not a private relay counts as "their email"
    const realEmail = isEmail(claimed) && String(claims.email_verified) === "true" && String(claims.is_private_email) !== "true" && !claimed.endsWith("@privaterelay.appleid.com") ? claimed : "";
    let user = await env.DB.prepare("SELECT id FROM users WHERE apple_sub = ?").bind(claims.sub).first(), created = false;
    if (!user && realEmail) {
      const existing = await env.DB.prepare("SELECT id FROM users WHERE email = ? AND apple_sub IS NULL").bind(realEmail).first();
      if (existing) { await env.DB.prepare("UPDATE users SET apple_sub = ?, email_verified = 1 WHERE id = ?").bind(claims.sub, existing.id).run(); user = existing; } // Apple confirmed this address
    }
    if (!user) {
      const id = crypto.randomUUID(), lang = LANGS.includes(body.lang) ? body.lang : "en";
      const name = cleanText(body.name, 24) || cleanText(realEmail.split("@")[0], 24) || "Friend";
      const email = realEmail || `a_${(await sha256(claims.sub)).replace(/[^a-z0-9]/gi, "").toLowerCase().slice(0, 16)}@${USERNAME_DOMAIN}`;
      await env.DB.prepare("INSERT INTO users (id, email, name, pw, lang, created_at, email_verified, apple_sub, pw_known) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)")
        .bind(id, email, name, await hashPassword(randomToken()), lang, now(), realEmail ? 1 : 0, claims.sub).run();
      try { if (body.ref) await recordReferral(env, request, { id, name }, body.ref); await rememberDevices(env, request, id); } catch (e) { console.error("referral failed", e.message); }
      user = { id }; created = true;
    }
    return json({ ok: true, created }, created ? 201 : 200, { "set-cookie": await createSession(env, user.id) });
  }

  // ===== signed in =====
  const user = await currentUser(request, env);
  if (!user) throw new HttpError("Please log in.", 401);
  const me = { id: user.id, email: user.email, name: user.name };

  if (path === "/api/referrals" && method === "GET") {
    const sum = await referralSummary(env, user.id);
    const people = (await env.DB.prepare("SELECT referred_id, referred_name, status, reason, created_at FROM referrals WHERE referrer_id = ? ORDER BY created_at DESC LIMIT 100").bind(user.id).all()).results;
    const ids = people.filter((p) => p.status === "pending").map((p) => p.referred_id);
    const days = {};
    if (ids.length) {
      const rows = (await env.DB.prepare(`SELECT created_by, COUNT(DISTINCT date(created_at, 'unixepoch')) AS d FROM entries WHERE created_by IN (${ids.map(() => "?").join(",")}) GROUP BY created_by`).bind(...ids).all()).results;
      for (const r of rows) days[r.created_by] = r.d;
    }
    const rewards = (await env.DB.prepare("SELECT amount_cents, status, created_at, sent_at FROM rewards WHERE user_id = ? ORDER BY created_at DESC").bind(user.id).all()).results;
    return json({ ...sum, link: `${appUrl}/r/${sum.code}`, days_needed: REF_DAYS, active_days_needed: REF_ACTIVE_DAYS,
      people: people.map((p) => ({ name: p.referred_name, status: p.status, reason: p.reason, created_at: p.created_at, active_days: days[p.referred_id] || 0 })), rewards });
  }

  if (path === "/api/me" && method === "GET") {
    try { await rememberDevices(env, request, user.id); } catch (e) { console.error("device", e.message); }
    let ref = null; try { ref = await referralSummary(env, user.id); } catch (e) { console.error("ref summary", e.message); }
    const m = await membership(env, user.id);
    const u = await env.DB.prepare("SELECT email_verified, tz, lang, mail_bills, mail_streak, mail_weekly, apple_sub, pw_known FROM users WHERE id = ?").bind(user.id).first();
    const k = await env.DB.prepare("SELECT created_at, last_used, uses FROM api_keys WHERE user_id = ?").bind(user.id).first();
    return json({ user: { ...me, verified: !!u.email_verified, has_email: hasRealEmail(user.email), apple: !!u.apple_sub, has_password: u.pw_known !== 0, tz: u.tz, lang: u.lang, mail: { bills: !!u.mail_bills, streak: !!u.mail_streak, weekly: !!u.mail_weekly },
      shortcut: k ? { created_at: k.created_at, last_used: k.last_used, uses: k.uses } : null, ref }, nest_id: m ? m.nest_id : null });
  }

  // ----- passkeys (signed in) -----
  if (path === "/api/passkeys" && method === "GET") {
    const rows = (await env.DB.prepare("SELECT id, name, created_at, last_used FROM passkeys WHERE user_id = ? ORDER BY created_at").bind(user.id).all()).results;
    return json({ passkeys: rows });
  }
  if (path === "/api/passkeys/options" && method === "POST") {
    const challenge = randomToken();
    await env.DB.prepare("INSERT INTO challenges (id, user_id, kind, expires_at) VALUES (?, ?, 'register', ?)").bind(challenge, user.id, now() + 300).run();
    const existing = (await env.DB.prepare("SELECT id FROM passkeys WHERE user_id = ?").bind(user.id).all()).results.map((r) => ({ type: "public-key", id: r.id }));
    return json({
      challenge, rp: { id: rpOrigin(env, url).hostname, name: "Honeybun" },
      user: { id: b64u(enc.encode(user.id)), name: user.email, displayName: user.name },
      pubKeyCredParams: [{ type: "public-key", alg: -7 }, { type: "public-key", alg: -257 }],
      authenticatorSelection: { residentKey: "required", userVerification: "preferred" },
      excludeCredentials: existing, timeout: 120000, attestation: "none",
    });
  }
  if (path === "/api/passkeys" && method === "POST") {
    const count = await env.DB.prepare("SELECT COUNT(*) AS n FROM passkeys WHERE user_id = ?").bind(user.id).first();
    if (count.n >= 10) throw new HttpError("You already have 10 passkeys. Remove one first.");
    const id = cleanText(body.id, 1024), alg = Number(body.alg), pub = String(body.publicKey || "");
    if (!id || ![-7, -257].includes(alg) || !pub) throw new HttpError("Your browser didn't return a usable passkey. Try a newer browser.");
    const clientData = fromB64u(String(body.clientDataJSON || "")), authData = fromB64u(String(body.authenticatorData || ""));
    const ch = await checkClientData(env, clientData, "webauthn.create", "register", url);
    if (ch.user_id !== user.id) throw new HttpError("Bad passkey data.");
    const counter = await checkAuthData(env, authData, url, false);
    try { await crypto.subtle.importKey("spki", fromB64u(pub), alg === -7 ? { name: "ECDSA", namedCurve: "P-256" } : { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]); }
    catch { throw new HttpError("Your browser didn't return a usable passkey. Try a newer browser."); }
    if (await env.DB.prepare("SELECT 1 FROM passkeys WHERE id = ?").bind(id).first()) throw new HttpError("That passkey is already registered.", 409);
    await env.DB.prepare("INSERT INTO passkeys (id, user_id, public_key, alg, counter, name, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
      .bind(id, user.id, pub, alg, counter, cleanText(body.name, 40) || "Passkey", now()).run();
    return json({ ok: true }, 201);
  }
  const pkId = path.match(/^\/api\/passkeys\/(.+)$/);
  if (pkId && method === "DELETE") {
    await env.DB.prepare("DELETE FROM passkeys WHERE id = ? AND user_id = ?").bind(decodeURIComponent(pkId[1]), user.id).run();
    return json({ ok: true });
  }
  if (pkId && method === "PATCH") {
    await env.DB.prepare("UPDATE passkeys SET name = ? WHERE id = ? AND user_id = ?").bind(cleanText(body.name, 40) || "Passkey", decodeURIComponent(pkId[1]), user.id).run();
    return json({ ok: true });
  }

  // ----- push notifications (signed in) -----
  if (path === "/api/push/subscribe" && method === "POST") {
    const endpoint = String(body.endpoint || "");
    if (!/^https:\/\/[^\s]{10,2000}$/.test(endpoint)) throw new HttpError("Bad subscription.");
    await env.DB.prepare("INSERT OR REPLACE INTO push_subs (endpoint, user_id, created_at) VALUES (?, ?, ?)").bind(endpoint, user.id, now()).run();
    return json({ ok: true });
  }
  if (path === "/api/push/subscribe" && method === "DELETE") {
    await env.DB.prepare("DELETE FROM push_subs WHERE endpoint = ? AND user_id = ?").bind(String(body.endpoint || ""), user.id).run();
    return json({ ok: true });
  }
  if (path === "/api/push/latest" && method === "GET") {
    const row = await env.DB.prepare("SELECT kind FROM challenges WHERE id = ? AND expires_at > ?").bind("push:" + user.id, now()).first();
    let text = null; try { text = row ? JSON.parse(row.kind) : null; } catch {}
    return json({ title: "Honeybun", body: text ? text.body : "Bun has something for you 🐰", url: "/" });
  }

  // iPhone app: register the phone for real push notifications, and mint the token the widget and Siri use
  if (path === "/api/push/apns" && method === "POST") {
    const token = String(body.token || "");
    if (!/^[0-9a-fA-F]{32,200}$/.test(token)) throw new HttpError("Bad device token.");
    await env.DB.prepare("INSERT OR REPLACE INTO apns_tokens (token, user_id, created_at) VALUES (?, ?, ?)").bind(token.toLowerCase(), user.id, now()).run();
    return json({ ok: true });
  }
  // "Send me a test notification": tells you in plain words whether a phone is registered and what Apple said
  if (path === "/api/push/test" && method === "POST") {
    if (await limited(env, "pushtest:" + user.id, 10, 3600)) throw new HttpError("Too many tests. Try again later.", 429);
    await recordAttempt(env, "pushtest:" + user.id);
    if (!env.APNS_KEY || !env.APNS_KEY_ID || !env.APNS_TEAM_ID) return json({ ok: false, step: "server", message: "Push isn't set up on the server yet." });
    const toks = (await env.DB.prepare("SELECT token FROM apns_tokens WHERE user_id = ?").bind(user.id).all()).results;
    if (!toks.length) return json({ ok: false, step: "phone", message: "No phone has signed up for notifications yet. Allow notifications for Honeybun in your iPhone Settings, then reopen the app." });
    const jwt = await apnsToken(env), topic = env.APNS_TOPIC || "me.honeybun.app";
    const payload = JSON.stringify({ aps: { alert: { title: "Honeybun", body: "Test notification. It works! 🐰" }, sound: "default" }, kind: "test" });
    const out = [];
    for (const t of toks) {
      for (const h of ["api.push.apple.com", "api.sandbox.push.apple.com"]) {
        const res = await fetch(`https://${h}/3/device/${t.token}`, { method: "POST", headers: { authorization: `bearer ${jwt}`, "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10" }, body: payload });
        const why = res.ok ? "" : await res.text().catch(() => "");
        out.push({ host: h.includes("sandbox") ? "sandbox" : "production", status: res.status, why });
        if (res.ok) break;
      }
    }
    const sent = out.some((o) => o.status === 200);
    return json({ ok: sent, step: sent ? "sent" : "apple", message: sent ? "Sent! It should arrive in a few seconds." : "Apple said no: " + out.map((o) => `${o.host} ${o.status} ${o.why}`).join(" | "), tokens: toks.length });
  }
  if (path === "/api/push/apns" && method === "DELETE") {
    await env.DB.prepare("DELETE FROM apns_tokens WHERE token = ? AND user_id = ?").bind(String(body.token || "").toLowerCase(), user.id).run();
    return json({ ok: true });
  }
  if (path === "/api/app/token" && method === "POST") {
    if (await limited(env, "apptok:" + user.id, 20, 3600)) throw new HttpError("Too many tries. Try again in an hour.", 429);
    await recordAttempt(env, "apptok:" + user.id);
    const token = "hb_app_" + randomToken();
    await env.DB.prepare("INSERT INTO app_tokens (token_hash, user_id, created_at) VALUES (?, ?, ?)").bind(await sha256(token), user.id, now()).run();
    return json({ ok: true, token }, 201);
  }
  if (path === "/api/app/token" && method === "DELETE") {
    await env.DB.prepare("DELETE FROM app_tokens WHERE user_id = ?").bind(user.id).run();
    return json({ ok: true });
  }

  // username accounts: make a fresh recovery code (the old one stops working)
  if (path === "/api/recovery/new" && method === "POST") {
    if (hasRealEmail(user.email)) throw new HttpError("Accounts with an email reset their password by email.");
    if (await limited(env, "rcnew:" + user.id, 10, 3600)) throw new HttpError("Too many tries. Try again in an hour.", 429);
    await recordAttempt(env, "rcnew:" + user.id);
    const code = newRecoveryCode();
    await env.DB.prepare("UPDATE users SET recovery_hash = ? WHERE id = ?").bind(await sha256(recoveryKey(code)), user.id).run();
    return json({ ok: true, recovery_code: code });
  }
  // Shortcut key: one per person, shown once. Making a new one replaces the old one.
  if (path === "/api/shortcut/key" && method === "POST") {
    if (await limited(env, "key:" + user.id, 10, 3600)) throw new HttpError("Too many new keys. Try again in an hour.", 429);
    await recordAttempt(env, "key:" + user.id);
    const token = "hb_" + randomToken();
    await env.DB.batch([
      env.DB.prepare("DELETE FROM api_keys WHERE user_id = ?").bind(user.id),
      env.DB.prepare("INSERT INTO api_keys (token_hash, user_id, created_at) VALUES (?, ?, ?)").bind(await sha256(token), user.id, now()),
    ]);
    return json({ ok: true, key: token, url: `${appUrl}/api/log` }, 201);
  }
  if (path === "/api/shortcut/key" && method === "DELETE") {
    await env.DB.prepare("DELETE FROM api_keys WHERE user_id = ?").bind(user.id).run();
    return json({ ok: true });
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
    if (body.tz !== undefined) {
      const tz = cleanText(body.tz, 60);
      try { new Intl.DateTimeFormat("en", { timeZone: tz }); } catch { throw new HttpError("Unknown time zone."); }
      await env.DB.prepare("UPDATE users SET tz = ? WHERE id = ?").bind(tz, user.id).run();
    }
    if (body.lang !== undefined) {
      if (!LANGS.includes(body.lang)) throw new HttpError("Unknown language.");
      await env.DB.prepare("UPDATE users SET lang = ? WHERE id = ?").bind(body.lang, user.id).run();
    }
    for (const [k, col] of [["mail_bills", "mail_bills"], ["mail_streak", "mail_streak"], ["mail_weekly", "mail_weekly"]])
      if (body[k] !== undefined) await env.DB.prepare(`UPDATE users SET ${col} = ? WHERE id = ?`).bind(body[k] ? 1 : 0, user.id).run();
    if (body.name === undefined && body.emoji === undefined && body.color === undefined) return json({ ok: true });
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

  if (path === "/api/email/resend" && method === "POST") {
    if (await limited(env, "verifymail:" + user.id, 3, 3600)) throw new HttpError("We already sent a few. Check your inbox and spam, or try again in an hour.", 429);
    const u = await env.DB.prepare("SELECT email_verified, lang FROM users WHERE id = ?").bind(user.id).first();
    if (u.email_verified) return json({ ok: true, already: true });
    await recordAttempt(env, "verifymail:" + user.id);
    await sendVerify(env, { ...me, lang: u.lang }, appUrl);
    return json({ ok: true });
  }

  if (path === "/api/account/export" && method === "GET") {
    const m = await membership(env, user.id);
    const out = { exported_at: new Date().toISOString(), account: me, budget: null };
    if (m) {
      const q = (sql, ...a) => env.DB.prepare(sql).bind(...a);
      const n = m.nest_id;
      const [nest, members, entries, recurring, goals, jar, budgets, debts, pays, settles] = await env.DB.batch([
        q("SELECT id, name, kind, accent, created_at FROM nests WHERE id = ?", n),
        q("SELECT u.id, u.name, m.emoji, m.joined_at FROM members m JOIN users u ON u.id = m.user_id WHERE m.nest_id = ?", n),
        q("SELECT id, member_id, type, amount_cents, label, category, shared, split_mode, split_value, private, date FROM entries WHERE nest_id = ? AND (private = 0 OR member_id = ?) ORDER BY date", n, user.id),
        q("SELECT id, type, label, amount_cents, category, member_id, shared, freq, anchor_date FROM recurring WHERE nest_id = ?", n),
        q("SELECT id, name, emoji, target_cents, saved_cents FROM goals WHERE nest_id = ?", n),
        q("SELECT id, goal_id, member_id, amount_cents, created_at FROM jar_moves WHERE nest_id = ?", n),
        q("SELECT category, limit_cents FROM budgets WHERE nest_id = ?", n),
        q("SELECT id, name, start_cents, apr_bp, min_cents FROM debts WHERE nest_id = ?", n),
        q("SELECT id, debt_id, member_id, amount_cents, date FROM debt_payments WHERE nest_id = ?", n),
        q("SELECT id, from_id, to_id, amount_cents, date FROM settlements WHERE nest_id = ?", n),
      ]);
      out.budget = { ...nest.results[0], members: members.results, entries: entries.results, bills_and_paydays: recurring.results, savings_goals: goals.results,
        savings_moves: jar.results, monthly_budgets: budgets.results, debts: debts.results, debt_payments: pays.results, settle_ups: settles.results };
    }
    return new Response(JSON.stringify(out, null, 2), { headers: { "content-type": "application/json; charset=utf-8", "content-disposition": 'attachment; filename="honeybun-data.json"', ...SEC_HEADERS } });
  }

  if (path === "/api/account/delete" && method === "POST") {
    if (await limited(env, "delete:" + user.id, 5, 900)) throw new HttpError("Too many tries. Wait 15 minutes.", 429);
    const row = await env.DB.prepare("SELECT pw, pw_known, apple_sub FROM users WHERE id = ?").bind(user.id).first();
    if (row.pw_known === 0) {
      // no password to type (Sign in with Apple / passkey): confirm in words, and only right after a fresh login
      if (body.confirm !== "DELETE") throw new HttpError("Type DELETE to confirm.");
      const sess = await env.DB.prepare("SELECT expires_at FROM sessions WHERE token_hash = ?").bind(user.session).first();
      if (!sess || now() - (sess.expires_at - SESSION_DAYS * 86400) > 600) throw new HttpError("For your safety, log in again, then delete your account right away.", 403);
    } else if (!(await verifyPassword(String(body.password ?? ""), row.pw))) { await recordAttempt(env, "delete:" + user.id); throw new HttpError("That password is wrong."); }
    // Apple wants the Sign in with Apple link revoked when the account goes away (only possible when the Apple key is configured)
    if (row.apple_sub && body.apple_authorization_code) { try { await revokeApple(env, String(body.apple_authorization_code)); } catch (e) { console.error("apple revoke failed", e.message); } }
    const m = await membership(env, user.id);
    const stmts = [];
    if (m) {
      stmts.push(env.DB.prepare("DELETE FROM entries WHERE nest_id = ? AND member_id = ? AND private = 1").bind(m.nest_id, user.id));
      stmts.push(env.DB.prepare("DELETE FROM members WHERE user_id = ?").bind(user.id));
    }
    stmts.push(env.DB.prepare("DELETE FROM messages WHERE user_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM referrals WHERE referrer_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("UPDATE referrals SET referred_name = '', status = CASE WHEN status = 'pending' THEN 'rejected' ELSE status END, reason = CASE WHEN status = 'pending' THEN 'left' ELSE reason END WHERE referred_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM devices WHERE user_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM rewards WHERE user_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM password_resets WHERE user_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM verify_tokens WHERE user_id = ?").bind(user.id));
    stmts.push(env.DB.prepare("DELETE FROM users WHERE id = ?").bind(user.id));
    await env.DB.batch(stmts);
    if (m) {
      const left = await env.DB.prepare("SELECT COUNT(*) AS n FROM members WHERE nest_id = ?").bind(m.nest_id).first();
      if (left.n === 0) await env.DB.batch(["entries", "settlements", "jar_moves", "recurring", "goals", "budgets", "debts", "debt_payments", "messages", "custom_categories", "shopping_items", "month_carry"]
        .map((t) => env.DB.prepare(`DELETE FROM ${t} WHERE nest_id = ?`).bind(m.nest_id)).concat([env.DB.prepare("DELETE FROM nests WHERE id = ?").bind(m.nest_id)]));
    }
    return json({ ok: true }, 200, { "set-cookie": clearCookie });
  }

  if (path === "/api/nests" && method === "POST") {
    if (await membership(env, user.id)) throw new HttpError("You're already in a budget.", 409);
    const id = crypto.randomUUID();
    const kind = ["solo", "couple", "family"].includes(body.kind) ? body.kind : "couple";
    await env.DB.batch([
      env.DB.prepare("INSERT INTO nests (id, name, invite_code, kind, accent, goals_migrated, created_by, created_at) VALUES (?, ?, ?, ?, 'blush', 1, ?, ?)").bind(id, cleanText(body.name, 24), inviteCode(), kind, user.id, now()),
      env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at, setup_done) VALUES (?, ?, ?, ?, ?, 0)").bind(id, user.id, EMOJIS[0], COLORS[0], now()),
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
    await env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at, setup_done) VALUES (?, ?, ?, ?, ?, 0)").bind(nest.id, user.id, emoji, color, now()).run();
    await postToOthers(env, nest.id, user.id, "joined", { name: user.name }, `joined:${user.id}`);
    return json({ ok: true, nest_id: nest.id });
  }

  // Join a different budget with a code while you are alone in your own (checks the code first, so a typo can never cost you your budget)
  if (path === "/api/nests/switch" && method === "POST") {
    if (await limited(env, "join:" + user.id, 20, 3600)) throw new HttpError("Too many tries. Try again later.", 429);
    await recordAttempt(env, "join:" + user.id);
    if (body.confirm !== true) throw new HttpError("Please confirm first.");
    const code = String(body.code ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "");
    const target = await env.DB.prepare("SELECT id FROM nests WHERE invite_code = ?").bind(code).first();
    if (!target) throw new HttpError("That invite code doesn't match any budget. Check it and try again.", 404);
    const mine = await membership(env, user.id);
    if (!mine) throw new HttpError("Use Join with a code on the start screen.", 409);
    if (mine.nest_id === target.id) return json({ ok: true, nest_id: target.id });
    const here = await env.DB.prepare("SELECT COUNT(*) AS n FROM members WHERE nest_id = ?").bind(mine.nest_id).first();
    if (here.n > 1) throw new HttpError("Your budget has other people in it. Leave it in Settings first, then join this one.", 409);
    const members = (await env.DB.prepare("SELECT emoji, color FROM members WHERE nest_id = ?").bind(target.id).all()).results;
    if (members.length >= MAX_MEMBERS) throw new HttpError("This budget is full.", 409);
    const emoji = EMOJIS.find((e) => !members.some((m) => m.emoji === e)) || EMOJIS[0];
    const color = COLORS.find((c) => !members.some((m) => m.color === c)) || COLORS[0];
    // the code is good and there is room: now leave the empty-ish budget (deleting it, since you were its only member) and join
    await env.DB.batch(["entries", "settlements", "jar_moves", "recurring", "goals", "budgets", "debts", "debt_payments", "messages", "custom_categories", "shopping_items", "month_carry"].map((t) => env.DB.prepare(`DELETE FROM ${t} WHERE nest_id = ?`).bind(mine.nest_id))
      .concat([env.DB.prepare("DELETE FROM members WHERE user_id = ?").bind(user.id), env.DB.prepare("DELETE FROM nests WHERE id = ?").bind(mine.nest_id),
        env.DB.prepare("INSERT INTO members (nest_id, user_id, emoji, color, joined_at, setup_done) VALUES (?, ?, ?, ?, ?, 0)").bind(target.id, user.id, emoji, color, now())]));
    await postToOthers(env, target.id, user.id, "joined", { name: user.name }, `joined:${user.id}`);
    return json({ ok: true, nest_id: target.id });
  }

  // ----- everything below is inside a budget -----
  const nestId = await requireNest(env, user);

  if (path === "/api/nest" && method === "GET") {
    try { await generateInbox(env, request, user, nestId, false); } catch (e) { console.error("inbox gen", e.message); }
    const month = url.searchParams.get("month") || "";
    if (!/^\d{4}-\d{2}$/.test(month)) throw new HttpError("Bad month.");
    const since = new Date(Date.now() - 45 * 86400000).toISOString().slice(0, 10);
    const [nest, members, entries, sharedAll, settlements, recurring, logged, jar, goals, budgets, debts, debtPays, mine] = await env.DB.batch([
      env.DB.prepare("SELECT id, name, invite_code, accent, kind, rollover, joint, carry_mode FROM nests WHERE id = ?").bind(nestId),
      env.DB.prepare("SELECT u.id, u.name, m.emoji, m.color, m.xp, m.streak, m.best_streak, m.last_day, m.week_key, m.week_xp, m.logs FROM members m JOIN users u ON u.id = m.user_id WHERE m.nest_id = ? ORDER BY m.joined_at").bind(nestId),
      env.DB.prepare(
        `SELECT id, member_id, type, amount_cents, label, category, shared, split_mode, split_value, shares, private, date, recurring_id, occ_date, created_at
         FROM entries WHERE nest_id = ? AND date >= ? AND date <= ? AND (private = 0 OR member_id = ?) ORDER BY date DESC, created_at DESC`
      ).bind(nestId, month + "-01", month + "-31", user.id),
      env.DB.prepare("SELECT member_id, amount_cents, shares FROM entries WHERE nest_id = ? AND type = 'expense' AND shared = 1").bind(nestId),
      env.DB.prepare("SELECT id, from_id, to_id, amount_cents, date, created_at FROM settlements WHERE nest_id = ? ORDER BY date DESC, created_at DESC").bind(nestId),
      env.DB.prepare("SELECT id, type, label, amount_cents, category, member_id, shared, split_mode, split_value, freq, anchor_date, prev_amount_cents, price_changed_at FROM recurring WHERE nest_id = ? ORDER BY type DESC, label").bind(nestId),
      env.DB.prepare("SELECT recurring_id, occ_date FROM entries WHERE nest_id = ? AND recurring_id IS NOT NULL AND occ_date >= ?").bind(nestId, since),
      env.DB.prepare("SELECT id, goal_id, member_id, amount_cents, created_at FROM jar_moves WHERE nest_id = ? ORDER BY created_at DESC LIMIT 60").bind(nestId),
      env.DB.prepare("SELECT id, name, emoji, target_cents, saved_cents FROM goals WHERE nest_id = ? ORDER BY created_at").bind(nestId),
      env.DB.prepare("SELECT category, limit_cents FROM budgets WHERE nest_id = ?").bind(nestId),
      env.DB.prepare("SELECT d.id, d.name, d.start_cents, d.apr_bp, d.min_cents, COALESCE((SELECT SUM(p.amount_cents) FROM debt_payments p WHERE p.debt_id = d.id), 0) AS paid_cents FROM debts d WHERE d.nest_id = ? ORDER BY d.created_at").bind(nestId),
      env.DB.prepare("SELECT id, debt_id, member_id, amount_cents, date FROM debt_payments WHERE nest_id = ? ORDER BY date DESC, created_at DESC LIMIT 10").bind(nestId),
      env.DB.prepare("SELECT setup_done FROM members WHERE user_id = ?").bind(user.id),
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

    const shopping_open = (await env.DB.prepare("SELECT COUNT(*) AS n FROM shopping_items WHERE nest_id = ? AND done = 0").bind(nestId).first()).n;
    let carryRow = await env.DB.prepare("SELECT amount_cents, accepted FROM month_carry WHERE nest_id = ? AND month = ?").bind(nestId, month).first();
    let carryPending = null, carryPrev = null;
    {
      const nowYm = localNow((await env.DB.prepare("SELECT tz FROM users WHERE id = ?").bind(user.id).first())?.tz).date.slice(0, 7);
      if (month === nowYm) {
        const prev = prevMonth(month), pb = await monthBalance(env, nestId, prev);
        if (pb.entries > 0 || pb.carried !== 0) {
          carryPrev = { from: prev, amount_cents: pb.cents };
          // a remembered choice ("always" / "never") answers the question for you
          const mode = nest.results[0]?.carry_mode || "ask";
          if (!carryRow && mode !== "ask") {
            const accept = mode === "always";
            await env.DB.prepare("INSERT OR IGNORE INTO month_carry (nest_id, month, amount_cents, accepted, decided_by, created_at) VALUES (?, ?, ?, ?, NULL, ?)").bind(nestId, month, accept ? pb.cents : 0, accept ? 1 : 0, now()).run();
            carryRow = { amount_cents: accept ? pb.cents : 0, accepted: accept ? 1 : 0 };
            if (accept) await postMessage(env, user.id, nestId, "carry_auto", { amount: Math.abs(pb.cents), neg: pb.cents < 0, from: new Date(+prev.slice(0, 4), +prev.slice(5) - 1, 1).toLocaleDateString("en-US", { month: "long" }) }, "carry_auto:" + month);
          } else if (!carryRow) carryPending = { from: prev, amount_cents: pb.cents };
        }
      }
    }
    const categories = (await env.DB.prepare("SELECT id, name, emoji FROM custom_categories WHERE nest_id = ? ORDER BY created_at").bind(nestId).all()).results;
    return json({
      me, nest: nest.results[0], members: members.results, entries: entries.results, categories, shopping_open, carry_in: carryRow ? { amount_cents: carryRow.amount_cents, accepted: !!carryRow.accepted } : null, carry_pending: carryPending, carry_prev: carryPrev,
      balances, settlements: settlements.results.slice(0, 10), recurring: recurring.results,
      logged: logged.results, jar: jar.results, goals: goals.results, budgets: budgets.results,
      debts: debts.results, debt_payments: debtPays.results, setup_done: !!mine.results[0]?.setup_done,
      repeats: await topRepeats(env, nestId, user.id),
      carry: await budgetCarry(env, nestId, user.id, month),
      inbox: await env.DB.prepare("SELECT COUNT(*) AS unread, (SELECT id || '|' || kind || '|' || data FROM messages WHERE user_id = ?1 AND read_at IS NULL ORDER BY created_at DESC LIMIT 1) AS latest FROM messages WHERE user_id = ?1 AND read_at IS NULL").bind(user.id).first(),
    });
  }

  if (path === "/api/nest" && method === "PATCH") {
    if (body.name !== undefined) await env.DB.prepare("UPDATE nests SET name = ? WHERE id = ?").bind(cleanText(body.name, 24), nestId).run();
    if (body.kind !== undefined) {
      if (!["solo", "couple", "family"].includes(body.kind)) throw new HttpError("Unknown budget type.");
      await env.DB.prepare("UPDATE nests SET kind = ? WHERE id = ?").bind(body.kind, nestId).run();
    }
    if (body.carry_mode !== undefined) {
      if (!["ask", "always", "never"].includes(body.carry_mode)) throw new HttpError("Unknown carry-over choice.");
      await env.DB.prepare("UPDATE nests SET carry_mode = ? WHERE id = ?").bind(body.carry_mode, nestId).run();
    }
    if (body.joint !== undefined) {
      const on = body.joint && body.joint !== "false" ? 1 : 0;
      const cur = await env.DB.prepare("SELECT joint, kind FROM nests WHERE id = ?").bind(nestId).first();
      if (on && cur.kind !== "couple") throw new HttpError("Joint account is for couples.");
      await env.DB.prepare("UPDATE nests SET joint = ? WHERE id = ?").bind(on, nestId).run();
      // one shared pot: anything that was marked private joins it (otherwise it would silently drop out of the totals and the carry-over)
      if (on) await env.DB.prepare("UPDATE entries SET private = 0 WHERE nest_id = ? AND private = 1").bind(nestId).run();
      // the other person sees it change on their screen within seconds; tell them in their inbox and by push too
      if ((cur.joint ? 1 : 0) !== on) await postToOthers(env, nestId, user.id, "joint", { name: user.name, on: !!on }, "joint:" + crypto.randomUUID());
    }
    if (body.accent !== undefined) {
      if (!ACCENTS.includes(body.accent)) throw new HttpError("Unknown theme.");
      await env.DB.prepare("UPDATE nests SET accent = ? WHERE id = ?").bind(body.accent, nestId).run();
    }
    return json({ ok: true });
  }

  if (path === "/api/nest/invite" && method === "POST") {
    const code = inviteCode();
    await env.DB.prepare("UPDATE nests SET invite_code = ? WHERE id = ?").bind(code, nestId).run();
    return json({ ok: true, invite_code: code });
  }

  if (path === "/api/nest/leave" && method === "POST") {
    await env.DB.batch([env.DB.prepare("DELETE FROM members WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId), env.DB.prepare("DELETE FROM messages WHERE user_id = ?").bind(user.id)]);
    const left = await env.DB.prepare("SELECT COUNT(*) AS n FROM members WHERE nest_id = ?").bind(nestId).first();
    if (left.n === 0) {
      await env.DB.batch(["entries", "settlements", "jar_moves", "recurring", "goals", "budgets", "debts", "debt_payments", "messages", "custom_categories", "shopping_items", "month_carry"].map((t) => env.DB.prepare(`DELETE FROM ${t} WHERE nest_id = ?`).bind(nestId))
        .concat([env.DB.prepare("DELETE FROM nests WHERE id = ?").bind(nestId)]));
    }
    return json({ ok: true });
  }

  // ----- savings goals -----
  function readGoal() {
    const name = cleanText(body.name, 30);
    if (!name) throw new HttpError("Name your goal.");
    return { name, emoji: GOAL_EMOJIS.includes(body.emoji) ? body.emoji : GOAL_EMOJIS[0], target: toCents(body.target, "a target") };
  }
  if (path === "/api/goals" && method === "POST") {
    const g = readGoal(), id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO goals (id, nest_id, name, emoji, target_cents, saved_cents, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)").bind(id, nestId, g.name, g.emoji, g.target, now()).run();
    return json({ ok: true, id }, 201);
  }
  const goalId = path.match(/^\/api\/goals\/([0-9a-f-]{32,36})$/);
  if (goalId && method === "PATCH") {
    const g = readGoal();
    await env.DB.prepare("UPDATE goals SET name = ?, emoji = ?, target_cents = ? WHERE id = ? AND nest_id = ?").bind(g.name, g.emoji, g.target, goalId[1], nestId).run();
    return json({ ok: true });
  }
  if (goalId && method === "DELETE") {
    await env.DB.batch([
      env.DB.prepare("DELETE FROM jar_moves WHERE goal_id = ? AND nest_id = ?").bind(goalId[1], nestId),
      env.DB.prepare("DELETE FROM goals WHERE id = ? AND nest_id = ?").bind(goalId[1], nestId),
    ]);
    return json({ ok: true });
  }
  if (path === "/api/jar" && method === "POST") {
    const goal = await env.DB.prepare("SELECT id, saved_cents FROM goals WHERE id = ? AND nest_id = ?").bind(String(body.goal_id ?? ""), nestId).first();
    if (!goal) throw new HttpError("Pick a savings goal.");
    const cents = toCents(body.amount);
    const signed = body.direction === "out" ? -cents : cents;
    if (goal.saved_cents + signed < 0) throw new HttpError("You can't take out more than you've saved for this goal.");
    await env.DB.batch([
      env.DB.prepare("INSERT INTO jar_moves (id, nest_id, goal_id, member_id, amount_cents, created_at) VALUES (?, ?, ?, ?, ?, ?)").bind(crypto.randomUUID(), nestId, goal.id, user.id, signed, now()),
      env.DB.prepare("UPDATE goals SET saved_cents = saved_cents + ? WHERE id = ?").bind(signed, goal.id),
    ]);
    const g2 = await env.DB.prepare("SELECT name, target_cents, saved_cents FROM goals WHERE id = ?").bind(goal.id).first();
    if (signed > 0 && g2 && g2.saved_cents >= g2.target_cents && g2.saved_cents - signed < g2.target_cents) {
      for (const id of await memberIds(env, nestId)) await postMessage(env, id, nestId, "goal_done", { goal: g2.name }, `goal:${goal.id}:${g2.target_cents}`);
    }
    return json({ ok: true, reward: signed > 0 ? await award(env, request, user.id, nestId, "save") : null });
  }
  const jarDel = path.match(/^\/api\/jar\/([0-9a-f-]{32,36})$/);
  if (jarDel && method === "DELETE") {
    const move = await env.DB.prepare("SELECT amount_cents, goal_id FROM jar_moves WHERE id = ? AND nest_id = ?").bind(jarDel[1], nestId).first();
    if (!move) throw new HttpError("Not found.", 404);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM jar_moves WHERE id = ?").bind(jarDel[1]),
      env.DB.prepare("UPDATE goals SET saved_cents = MAX(0, saved_cents - ?) WHERE id = ?").bind(move.amount_cents, move.goal_id),
    ]);
    return json({ ok: true });
  }

  // ----- your own categories -----
  const readCat = () => {
    const name = cleanText(body.name, 20);
    if (!name) throw new HttpError("Give the category a name.");
    const em = String(body.emoji || "").trim();
    const emoji = /\p{Extended_Pictographic}/u.test(em) && em.length <= 12 ? em : "✨";
    return { name, emoji };
  };
  if (path === "/api/categories" && method === "POST") {
    const c = readCat();
    const n = (await env.DB.prepare("SELECT COUNT(*) AS n FROM custom_categories WHERE nest_id = ?").bind(nestId).first()).n;
    if (n >= MAX_CUSTOM) throw new HttpError(`You can make up to ${MAX_CUSTOM} of your own categories.`);
    const id = "c_" + Array.from(crypto.getRandomValues(new Uint8Array(6)), (b) => b.toString(16).padStart(2, "0")).join("");
    await env.DB.prepare("INSERT INTO custom_categories (id, nest_id, name, emoji, created_at) VALUES (?, ?, ?, ?, ?)").bind(id, nestId, c.name, c.emoji, now()).run();
    if (body.limit !== undefined && Number(body.limit) > 0 && Number(body.limit) <= 10_000_000)
      await env.DB.prepare("INSERT OR REPLACE INTO budgets (nest_id, category, limit_cents) VALUES (?, ?, ?)").bind(nestId, id, Math.round(Number(body.limit) * 100)).run();
    return json({ ok: true, id, name: c.name, emoji: c.emoji }, 201);
  }
  const catId = path.match(/^\/api\/categories\/(c_[0-9a-f]{12})$/);
  if (catId && method === "PATCH") {
    const c = readCat();
    const r = await env.DB.prepare("UPDATE custom_categories SET name = ?, emoji = ? WHERE id = ? AND nest_id = ?").bind(c.name, c.emoji, catId[1], nestId).run();
    if (!r.meta.changes) throw new HttpError("That category doesn't exist.", 404);
    return json({ ok: true });
  }
  if (catId && method === "DELETE") {
    // anything filed under it moves to Other, and its budget goes away
    await env.DB.batch([
      env.DB.prepare("UPDATE entries SET category = 'other' WHERE nest_id = ? AND category = ?").bind(nestId, catId[1]),
      env.DB.prepare("UPDATE recurring SET category = 'other' WHERE nest_id = ? AND category = ?").bind(nestId, catId[1]),
      env.DB.prepare("DELETE FROM budgets WHERE nest_id = ? AND category = ?").bind(nestId, catId[1]),
      env.DB.prepare("DELETE FROM custom_categories WHERE id = ? AND nest_id = ?").bind(catId[1], nestId),
    ]);
    return json({ ok: true });
  }

  // ----- shared shopping list -----
  if (path === "/api/shopping" && method === "GET") {
    const items = (await env.DB.prepare("SELECT id, label, added_by, done, done_by FROM shopping_items WHERE nest_id = ? ORDER BY done, CASE WHEN done = 1 THEN done_at ELSE created_at END DESC LIMIT 120").bind(nestId).all()).results;
    return json({ items: items.map((i) => ({ ...i, done: !!i.done })) });
  }
  if (path === "/api/shopping" && method === "POST") {
    const label = cleanText(body.label, 60);
    if (!label) throw new HttpError("Type what you need.");
    const n = (await env.DB.prepare("SELECT COUNT(*) AS n FROM shopping_items WHERE nest_id = ?").bind(nestId).first()).n;
    if (n >= 100) throw new HttpError("The list is full. Clear the checked items first.");
    const id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO shopping_items (id, nest_id, label, added_by, created_at) VALUES (?, ?, ?, ?, ?)").bind(id, nestId, label, user.id, now()).run();
    return json({ ok: true, id }, 201);
  }
  if (path === "/api/shopping/clear" && method === "POST") {
    await env.DB.prepare("DELETE FROM shopping_items WHERE nest_id = ? AND done = 1").bind(nestId).run();
    return json({ ok: true });
  }
  // "Done shopping?": log what you spent as groceries (split like any shared expense, unless it's a joint account) and clear the checked items
  if (path === "/api/shopping/checkout" && method === "POST") {
    const ids = await memberIds(env, nestId);
    const joint = !!(await env.DB.prepare("SELECT joint FROM nests WHERE id = ?").bind(nestId).first())?.joint;
    const shared = ids.length > 1 && !joint;
    const e = await readEntry(env, nestId, user, { type: "expense", amount: body.amount, member_id: user.id, label: cleanText(body.label, 40) || "Groceries", category: "groc", shared, split_mode: "equal", date: isDate(body.date) ? body.date : undefined });
    const entryId = await insertEntry(env, nestId, user, e);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM shopping_items WHERE nest_id = ? AND done = 1").bind(nestId),
      env.DB.prepare("UPDATE members SET inbox_gen_at = 0 WHERE nest_id = ?").bind(nestId),
    ]);
    if (e.shared) { try { await postToOthers(env, nestId, user.id, "shared_expense", { name: user.name, label: e.label, amount: e.amount }, `shared:${entryId}`); } catch (err) { console.error("shop notify", err.message); } }
    return json({ ok: true, id: entryId, reward: await award(env, request, user.id, nestId, "entry") }, 201);
  }
  const shopId = path.match(/^\/api\/shopping\/([0-9a-f-]{36})$/);
  if (shopId && method === "PATCH" && body.label !== undefined && body.done === undefined) {
    // rename an item (leaves checked/unchecked as it was)
    const label = cleanText(body.label, 60);
    if (!label) throw new HttpError("Type what you need.");
    const r = await env.DB.prepare("UPDATE shopping_items SET label = ? WHERE id = ? AND nest_id = ?").bind(label, shopId[1], nestId).run();
    if (!r.meta.changes) throw new HttpError("That item is gone.", 404);
    return json({ ok: true });
  }
  if (shopId && method === "PATCH") {
    const done = body.done && body.done !== "false" ? 1 : 0;
    const r = await env.DB.prepare("UPDATE shopping_items SET done = ?, done_by = ?, done_at = ? WHERE id = ? AND nest_id = ?").bind(done, done ? user.id : null, done ? now() : null, shopId[1], nestId).run();
    if (!r.meta.changes) throw new HttpError("That item is gone.", 404);
    return json({ ok: true });
  }
  if (shopId && method === "DELETE") {
    await env.DB.prepare("DELETE FROM shopping_items WHERE id = ? AND nest_id = ?").bind(shopId[1], nestId).run();
    return json({ ok: true });
  }

  // ----- carry over last month's balance -----
  if (path === "/api/carry" && method === "POST") {
    const month = String(body.month || "");
    if (!/^\d{4}-\d{2}$/.test(month)) throw new HttpError("Bad month.");
    const nowYm = localNow((await env.DB.prepare("SELECT tz FROM users WHERE id = ?").bind(user.id).first())?.tz).date.slice(0, 7);
    if (month > nowYm) throw new HttpError("That month hasn't started yet.");
    const had = await env.DB.prepare("SELECT 1 FROM month_carry WHERE nest_id = ? AND month = ?").bind(nestId, month).first();
    const change = !!body.change && body.change !== "false";
    if (had && !change) return json({ ok: true, already: true });
    if (had && month !== nowYm) throw new HttpError("Only this month's choice can be changed.");
    const accept = !!body.accept && body.accept !== "false";
    const bal = await monthBalance(env, nestId, prevMonth(month));
    await env.DB.prepare("INSERT INTO month_carry (nest_id, month, amount_cents, accepted, decided_by, created_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(nest_id, month) DO UPDATE SET amount_cents = excluded.amount_cents, accepted = excluded.accepted, decided_by = excluded.decided_by, created_at = excluded.created_at")
      .bind(nestId, month, accept ? bal.cents : 0, accept ? 1 : 0, user.id, now()).run();
    // "remember my choice": ask less next time (always carry over / never carry over); you can switch back in Settings
    if (body.remember) await env.DB.prepare("UPDATE nests SET carry_mode = ? WHERE id = ?").bind(accept ? "always" : "never", nestId).run();
    await postToOthers(env, nestId, user.id, "carry_done", { name: user.name, accepted: accept, amount: Math.abs(bal.cents), neg: bal.cents < 0, from: new Date(+prevMonth(month).slice(0, 4), +prevMonth(month).slice(5) - 1, 1).toLocaleDateString("en-US", { month: "long" }) }, "carry_done:" + month + (had ? ":" + crypto.randomUUID() : ""));
    return json({ ok: true, amount_cents: accept ? bal.cents : 0, accepted: accept });
  }

  // ----- monthly category budgets -----
  if (path === "/api/budgets" && method === "PUT") {
    const items = Array.isArray(body.items) ? body.items.slice(0, CATEGORIES.length + MAX_CUSTOM) : [];
    const customs = await customCategoryIds(env, nestId);
    const stmts = [env.DB.prepare("DELETE FROM budgets WHERE nest_id = ?").bind(nestId)];
    for (const it of items) {
      if (!CATEGORIES.includes(it.category) && !customs.has(it.category)) continue;
      const n = Number(it.limit);
      if (!Number.isFinite(n) || n <= 0) continue;
      if (n > 10_000_000) throw new HttpError("That budget is too big.");
      stmts.push(env.DB.prepare("INSERT INTO budgets (nest_id, category, limit_cents) VALUES (?, ?, ?)").bind(nestId, it.category, Math.round(n * 100)));
    }
    if (body.rollover !== undefined) {
      const cur = await env.DB.prepare("SELECT rollover FROM nests WHERE id = ?").bind(nestId).first();
      const on = body.rollover ? 1 : 0;
      // carrying starts the month it's switched on, so old months don't pile up
      stmts.push(on && !cur.rollover ? env.DB.prepare("UPDATE nests SET rollover = 1, rollover_since = ? WHERE id = ?").bind(localDay(request).slice(0, 7), nestId)
        : env.DB.prepare("UPDATE nests SET rollover = ? WHERE id = ?").bind(on, nestId));
    }
    stmts.push(env.DB.prepare("UPDATE members SET inbox_gen_at = 0 WHERE nest_id = ?").bind(nestId));
    await env.DB.batch(stmts);
    return json({ ok: true });
  }

  // ----- debts -----
  function readDebt() {
    const name = cleanText(body.name, 30);
    if (!name) throw new HttpError("Name the debt.");
    const apr = Number(body.apr ?? 0), min = Number(body.min ?? 0);
    if (!Number.isFinite(apr) || apr < 0 || apr > 100) throw new HttpError("Enter an interest rate from 0 to 100%.");
    if (!Number.isFinite(min) || min < 0 || min > 10_000_000) throw new HttpError("Enter a valid minimum payment.");
    return { name, start: toCents(body.balance, "a balance"), apr: Math.round(apr * 100), min: Math.round(min * 100) };
  }
  if (path === "/api/debts" && method === "POST") {
    const d = readDebt(), id = crypto.randomUUID();
    await env.DB.prepare("INSERT INTO debts (id, nest_id, name, start_cents, apr_bp, min_cents, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(id, nestId, d.name, d.start, d.apr, d.min, now()).run();
    return json({ ok: true, id }, 201);
  }
  const debtId = path.match(/^\/api\/debts\/([0-9a-f-]{36})$/);
  if (debtId && method === "PATCH") {
    const d = readDebt();
    await env.DB.prepare("UPDATE debts SET name = ?, start_cents = ?, apr_bp = ?, min_cents = ? WHERE id = ? AND nest_id = ?").bind(d.name, d.start, d.apr, d.min, debtId[1], nestId).run();
    return json({ ok: true });
  }
  if (debtId && method === "DELETE") {
    await env.DB.batch([
      env.DB.prepare("DELETE FROM debt_payments WHERE debt_id = ? AND nest_id = ?").bind(debtId[1], nestId),
      env.DB.prepare("DELETE FROM debts WHERE id = ? AND nest_id = ?").bind(debtId[1], nestId),
    ]);
    return json({ ok: true });
  }
  const debtPay = path.match(/^\/api\/debts\/([0-9a-f-]{36})\/pay$/);
  if (debtPay && method === "POST") {
    const debt = await env.DB.prepare("SELECT id, name FROM debts WHERE id = ? AND nest_id = ?").bind(debtPay[1], nestId).first();
    if (!debt) throw new HttpError("That debt doesn't exist anymore.", 404);
    const ids = await memberIds(env, nestId);
    const payer = ids.includes(body.member_id) ? body.member_id : user.id;
    const amount = toCents(body.amount), date = isDate(body.date) ? body.date : todayStr();
    // also log it as an expense so it counts in the month's spending
    const entryId = await insertEntry(env, nestId, user, {
      type: "expense", amount, memberId: payer, shared: 0, priv: 0, split: { mode: null, value: null }, shares: null,
      category: "debt", label: "Payment: " + debt.name, date,
    });
    await env.DB.prepare("INSERT INTO debt_payments (id, debt_id, nest_id, member_id, amount_cents, date, entry_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
      .bind(crypto.randomUUID(), debt.id, nestId, payer, amount, date, entryId, now()).run();
    const d2 = await env.DB.prepare("SELECT d.name, d.start_cents, (SELECT SUM(amount_cents) FROM debt_payments p WHERE p.debt_id = d.id) AS paid FROM debts d WHERE d.id = ?").bind(debt.id).first();
    if (d2 && d2.paid >= d2.start_cents && d2.paid - amount < d2.start_cents) {
      for (const id of await memberIds(env, nestId)) await postMessage(env, id, nestId, "debt_done", { debt: d2.name }, `debt:${debt.id}`);
    }
    return json({ ok: true, reward: await award(env, request, user.id, nestId, "debt") }, 201);
  }
  const payDel = path.match(/^\/api\/debt-payments\/([0-9a-f-]{36})$/);
  if (payDel && method === "DELETE") {
    const p = await env.DB.prepare("SELECT entry_id FROM debt_payments WHERE id = ? AND nest_id = ?").bind(payDel[1], nestId).first();
    if (!p) throw new HttpError("Not found.", 404);
    await env.DB.batch([
      env.DB.prepare("DELETE FROM debt_payments WHERE id = ?").bind(payDel[1]),
      env.DB.prepare("DELETE FROM entries WHERE id = ? AND nest_id = ?").bind(p.entry_id || "", nestId),
    ]);
    return json({ ok: true });
  }

  // ----- Bun's inbox -----
  if (path === "/api/inbox" && method === "GET") {
    await generateInbox(env, request, user, nestId, true);
    const rows = (await env.DB.prepare("SELECT id, kind, data, created_at, read_at FROM messages WHERE user_id = ? ORDER BY created_at DESC LIMIT 80").bind(user.id).all()).results;
    return json({ messages: rows.reverse().map((r) => ({ ...r, data: JSON.parse(r.data || "{}") })) });
  }
  // tiny check the Windows app makes about once a minute while minimized, to light up its taskbar badge
  if (path === "/api/inbox/count" && method === "GET") {
    await generateInbox(env, request, user, nestId, false);
    const r = await env.DB.prepare("SELECT COUNT(*) AS n FROM messages WHERE user_id = ? AND read_at IS NULL").bind(user.id).first();
    return json({ unread: r.n });
  }
  if (path === "/api/inbox/read" && method === "POST") {
    await env.DB.prepare("UPDATE messages SET read_at = ? WHERE user_id = ? AND read_at IS NULL").bind(now(), user.id).run();
    return json({ ok: true });
  }

  // ----- search -----
  if (path === "/api/search" && method === "GET") {
    const q = cleanText(url.searchParams.get("q"), 40), type = url.searchParams.get("type"), cat = url.searchParams.get("cat"), who = url.searchParams.get("member");
    let sql = "SELECT id, member_id, type, amount_cents, label, category, shared, split_mode, split_value, shares, private, date, recurring_id, occ_date, created_at FROM entries WHERE nest_id = ? AND (private = 0 OR member_id = ?)";
    const args = [nestId, user.id];
    if (q) { sql += " AND label LIKE ? ESCAPE '\\'"; args.push("%" + q.replace(/[\\%_]/g, (c) => "\\" + c) + "%"); }
    if (type === "income" || type === "expense") { sql += " AND type = ?"; args.push(type); }
    if (CATEGORIES.includes(cat) || isCustomId(cat)) { sql += " AND category = ?"; args.push(cat); }
    if (who) { sql += " AND member_id = ?"; args.push(who); }
    const min = Number(url.searchParams.get("min")), max = Number(url.searchParams.get("max"));
    if (url.searchParams.get("min") && Number.isFinite(min) && min > 0) { sql += " AND amount_cents >= ?"; args.push(Math.round(min * 100)); }
    if (url.searchParams.get("max") && Number.isFinite(max) && max > 0) { sql += " AND amount_cents <= ?"; args.push(Math.round(max * 100)); }
    const from = url.searchParams.get("from") || "", to = url.searchParams.get("to") || "";
    if (isDate(from)) { sql += " AND date >= ?"; args.push(from); }
    if (isDate(to)) { sql += " AND date <= ?"; args.push(to); }
    sql += " ORDER BY date DESC, created_at DESC LIMIT 150";
    return json({ entries: (await env.DB.prepare(sql).bind(...args).all()).results });
  }

  // ----- year overview + export -----
  if (path === "/api/year" && method === "GET") {
    const year = url.searchParams.get("year") || "";
    if (!/^\d{4}$/.test(year)) throw new HttpError("Bad year.");
    const from = Date.UTC(+year, 0, 1) / 1000, to = Date.UTC(+year + 1, 0, 1) / 1000;
    const [entries, jar] = await env.DB.batch([
      env.DB.prepare("SELECT type, amount_cents, category, label, member_id, shared, private, date FROM entries WHERE nest_id = ? AND date >= ? AND date <= ? AND (private = 0 OR member_id = ?) ORDER BY date")
        .bind(nestId, year + "-01-01", year + "-12-31", user.id),
      env.DB.prepare("SELECT amount_cents, created_at FROM jar_moves WHERE nest_id = ? AND created_at >= ? AND created_at < ?").bind(nestId, from, to),
    ]);
    return json({ entries: entries.results, jar: jar.results });
  }

  // ----- first-time setup -----
  if (path === "/api/setup/done" && method === "POST") {
    const already = await env.DB.prepare("SELECT setup_done FROM members WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId).first();
    await env.DB.prepare("UPDATE members SET setup_done = 1 WHERE user_id = ? AND nest_id = ?").bind(user.id, nestId).run();
    return json({ ok: true, reward: already && !already.setup_done ? await award(env, request, user.id, nestId, "setup") : null });
  }

  // ----- settle up -----
  if (path === "/api/settlements" && method === "POST") {
    const ids = await memberIds(env, nestId);
    const from = String(body.from_id ?? ""), to = String(body.to_id ?? "");
    if (!ids.includes(from) || !ids.includes(to) || from === to) throw new HttpError("Pick who paid who.");
    await env.DB.prepare("INSERT INTO settlements (id, nest_id, from_id, to_id, amount_cents, date, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
      .bind(crypto.randomUUID(), nestId, from, to, toCents(body.amount), isDate(body.date) ? body.date : todayStr(), user.id, now()).run();
    const other = user.id === from ? to : from, amt = toCents(body.amount);
    if (other !== user.id) await postMessage(env, other, nestId, "settled", { name: user.name, amount: amt, you_paid: other === from });
    return json({ ok: true, reward: await award(env, request, user.id, nestId, "settle") }, 201);
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
    const id = await insertEntry(env, nestId, user, e, rid, occ);
    if (e.type === "expense") await env.DB.prepare("UPDATE members SET inbox_gen_at = 0 WHERE nest_id = ?").bind(nestId).run();
    if (e.shared && !body.restore) await postToOthers(env, nestId, user.id, "shared_expense", { name: user.name, label: e.label, amount: e.amount }, `shared:${id}`);
    else if (!body.restore && !e.priv && (await isJoint(env, nestId))) {
      // a joint account is one shared pot: your partner hears about everything that goes into it
      try { await postToOthers(env, nestId, user.id, "joint_entry", { name: user.name, label: e.label, amount: e.amount }, `joint:${id}`); } catch (err) { console.error("joint notify", err.message); }
    }
    return json({ ok: true, id, reward: body.restore ? null : await award(env, request, user.id, nestId, "entry") }, 201);
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
    await env.DB.prepare("UPDATE members SET inbox_gen_at = 0 WHERE nest_id = ?").bind(nestId).run();
    return json({ ok: true, id, reward: await award(env, request, user.id, nestId, "plan") }, 201);
  }
  const recId = path.match(/^\/api\/recurring\/([0-9a-f-]{36})$/);
  if (recId && method === "PATCH") {
    const r = await readRecurring();
    const before = await env.DB.prepare("SELECT amount_cents FROM recurring WHERE id = ? AND nest_id = ?").bind(recId[1], nestId).first();
    await env.DB.prepare(
      "UPDATE recurring SET type = ?, label = ?, amount_cents = ?, category = ?, member_id = ?, shared = ?, split_mode = ?, split_value = ?, freq = ?, anchor_date = ? WHERE id = ? AND nest_id = ?"
    ).bind(r.type, r.label, r.amount, r.category, r.memberId, r.shared, r.split.mode, r.split.value, r.freq, r.anchor, recId[1], nestId).run();
    // a changed price is remembered for a while so Bun can say "Netflix went from $15.49 to $17.99"
    if (before && before.amount_cents !== r.amount && r.type === "expense") {
      await env.DB.prepare("UPDATE recurring SET prev_amount_cents = ?, price_changed_at = ? WHERE id = ? AND nest_id = ?").bind(before.amount_cents, todayStr(), recId[1], nestId).run();
    }
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
    return json({ ok: true, reward: await award(env, request, user.id, nestId, r.type === "income" ? "payday" : "bill") }, 201);
  }

  throw new HttpError("Not found.", 404);
}

// give every browser a long-lived device id cookie (used to spot self-referrals)
function withDevice(request, res) {
  if (!readCookie(request, DEV_COOKIE)) res.headers.append("set-cookie", `${DEV_COOKIE}=${randomToken()}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${5 * 365 * 86400}`);
  return res;
}

// The Windows installer is built on GitHub, but people download it from honeybun.me:
// the Worker fetches the latest build and hands it over as Honeybun-Setup.exe (cached at the edge for 10 minutes).
const WINDOWS_INSTALLER = "https://github.com/mustache-1/honeybun/releases/latest/download/Honeybun-Setup.exe";
// The newest app version, read from the latest release. The Windows app asks this to decide whether to update itself.
async function windowsVersion() {
  let res = null;
  try { res = await fetch(WINDOWS_INSTALLER.replace(/[^/]+$/, "version.txt") + "?v=1", { redirect: "follow", cf: { cacheEverything: true, cacheTtlByStatus: { "200-299": 300, "300-599": 0 } } }); } catch (e) { res = null; }
  const v = res && res.ok ? (await res.text()).trim() : "";
  if (!/^\d+(\.\d+){1,3}$/.test(v)) return new Response("unavailable", { status: 503, headers: { "cache-control": "no-store" } });
  return new Response(v, { headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "public, max-age=300" } });
}

async function downloadWindows(request) {
  if (request.method !== "GET" && request.method !== "HEAD") return new Response("Method not allowed", { status: 405 });
  let res;
  try { res = await fetch(WINDOWS_INSTALLER + "?v=4", { redirect: "follow", cf: { cacheEverything: true, cacheTtlByStatus: { "200-299": 600, "300-599": 0 } } }); } catch (e) { console.error("installer fetch failed", e.message); res = null; }
  if (!res || !res.ok) {
    console.error("installer not available", res && res.status);
    return new Response(`<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Honeybun for Windows</title>
<body style="font:16px system-ui;background:#141217;color:#f8f4f8;display:grid;place-items:center;height:100vh;margin:0;text-align:center"><div><p>The Windows download is being updated. Try again in a few minutes 🐰</p><p><a style="color:#ea78a4" href="/">Back to Honeybun</a></p></div>`,
      { status: 503, headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "retry-after": "300" } });
  }
  const headers = { "content-type": "application/octet-stream", "content-disposition": 'attachment; filename="Honeybun-Setup.exe"', "cache-control": "public, max-age=600", "x-content-type-options": "nosniff" };
  const len = res.headers.get("content-length"); if (len) headers["content-length"] = len;
  return new Response(request.method === "HEAD" ? null : res.body, { status: 200, headers });
}

// Halloween (Sept 29 to Oct 31): the install manifest points at the witch-hat Bun icons, so phones that
// installed the app pick the new icon up on their own. Everything else is the normal manifest.
async function seasonalManifest(request, env) {
  const res = await env.ASSETS.fetch(request);
  const d = new Date(), m = d.getUTCMonth(), day = d.getUTCDate();
  if (!(m === 9 || (m === 8 && day >= 29))) return res;
  const man = await res.json();
  man.icons = man.icons.map((i) => ({ ...i, src: i.src.replace(/\.png$/, "-halloween.png") }));
  return new Response(JSON.stringify(man), { headers: { "content-type": "application/manifest+json", "cache-control": "public, max-age=3600" } });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/download/windows/version") return windowsVersion();
    if (url.pathname === "/download/windows" || url.pathname === "/download/windows/") return downloadWindows(request);
    if (url.pathname === "/manifest.webmanifest") return seasonalManifest(request, env);
    // lets the iPhone app use honeybun.me passkeys (webcredentials); needs APPLE_TEAM_ID in the site's variables
    if (url.pathname === "/.well-known/apple-app-site-association") {
      if (!env.APPLE_TEAM_ID) return new Response("Not found", { status: 404 });
      const appID = env.APPLE_TEAM_ID + ".me.honeybun.app";
      // passkeys (webcredentials) and Universal Links: only the email / invite links open the app, the rest of the site stays in Safari
      const aasa = { webcredentials: { apps: [appID] }, applinks: { details: [{ appIDs: [appID], components: [{ "/": "/verify/*" }, { "/": "/reset/*" }, { "/": "/join/*" }] }] } };
      return new Response(JSON.stringify(aasa), { headers: { "content-type": "application/json", "cache-control": "public, max-age=3600" } });
    }
    if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);

    // CSRF protection: changes must come from our own site, as JSON
    // /api/log is called by iPhone Shortcuts with a Bearer key, never a cookie, so it can't be forged cross-site
    if (request.method !== "GET" && url.pathname !== "/api/log") {
      let sameOrigin = false;
      try { sameOrigin = new URL(request.headers.get("origin")).host === url.host; } catch {}
      if (!sameOrigin) return fail("Request blocked.", 403);
      if (!(request.headers.get("content-type") || "").includes("application/json")) return fail("Expected JSON.", 415);
    }
    if (url.pathname === "/api/log" && request.method !== "POST") return fail("Not found.", 404);

    try {
      await ensureSchema(env);
      return withDevice(request, await handle(request, env, url));
    } catch (e) {
      if (e instanceof HttpError) return withDevice(request, fail(e.message, e.status));
      console.error(e);
      return fail("Something went wrong on our side. Try again.", 500);
    }
  },

  // runs every hour (cron in wrangler.jsonc): reminder emails, plus cleanup once a day
  async scheduled(_event, env) {
    await ensureSchema(env);
    if (new Date().getUTCHours() === 4) {
      await env.DB.batch([
        env.DB.prepare("DELETE FROM sessions WHERE expires_at < ?").bind(now()),
        env.DB.prepare("DELETE FROM password_resets WHERE expires_at < ?").bind(now()),
        env.DB.prepare("DELETE FROM verify_tokens WHERE expires_at < ?").bind(now()),
        env.DB.prepare("DELETE FROM messages WHERE created_at < ?").bind(now() - 60 * 86400),
        env.DB.prepare("DELETE FROM auth_attempts WHERE ts < ?").bind(now() - 86400),
        env.DB.prepare("DELETE FROM challenges WHERE expires_at < ?").bind(now()),
      ]);
    }
    try { await carryNudges(env); } catch (e) { console.error("carry nudges", e.message); }
    if (env.RESEND_API_KEY) await sendReminders(env);
    if (env.VAPID_PRIVATE_KEY || env.APNS_KEY) await pushReminders(env);
    try { await checkReferrals(env); } catch (e) { console.error("referrals", e.message); }
  },
};

// Bills due (9am) and streak nudges (7pm) as push notifications, for anyone with a subscribed device
async function pushReminders(env) {
  const people = (await env.DB.prepare(
    `SELECT DISTINCT u.id, u.name, u.tz, u.lang, u.last_bill_push, u.last_streak_push, u.last_tip_push, m.nest_id, m.streak, m.last_day
     FROM users u JOIN members m ON m.user_id = u.id WHERE u.id IN (SELECT user_id FROM push_subs UNION SELECT user_id FROM apns_tokens)`
  ).all()).results;
  const cache = {};
  for (const p of people) {
    try {
      const L = localNow(p.tz);
      if (L.hour === 9 && p.last_bill_push !== L.date) {
        const due = (await nestBillsDue(env, cache, p.nest_id, L.date, sDay(pDay(L.date) + 3 * dayMs))).filter((x) => x.r.shared || x.r.member_id === p.id);
        if (due.length) {
          const d = due[0], diff = Math.round((pDay(d.d) - pDay(L.date)) / dayMs);
          const when = { en: ["today", "tomorrow", `in ${diff} days`], es: ["hoy", "mañana", `en ${diff} días`], zh: ["今天", "明天", `${diff} 天后`] }[PUSH_TEXT[p.lang] ? p.lang : "en"][Math.min(diff, 2)];
          await sendPush(env, p.id, pushText("bills", { n: due.length, label: d.r.label, amount: d.r.amount_cents, when }, p.lang));
          await env.DB.prepare("UPDATE users SET last_bill_push = ? WHERE id = ?").bind(L.date, p.id).run();
        }
      }
      if (L.hour === 19 && p.last_streak_push !== L.date && p.streak >= 2 && p.last_day === sDay(pDay(L.date) - dayMs)) {
        await sendPush(env, p.id, pushText("streak", { streak: p.streak }, p.lang));
        await env.DB.prepare("UPDATE users SET last_streak_push = ? WHERE id = ?").bind(L.date, p.id).run();
      }
      if (L.hour === 12 && p.last_tip_push !== L.date && (!p.last_tip_push || pDay(L.date) - pDay(p.last_tip_push) >= 3 * dayMs)) {
        const text = await bunTip(env, p, L);
        await sendPush(env, p.id, pushText("tip", { text }, p.lang));
        await env.DB.prepare("UPDATE users SET last_tip_push = ? WHERE id = ?").bind(L.date, p.id).run();
      }
    } catch (e) { console.error("push reminder failed", p.id, e.message); }
  }
}

// Bun's tip, sent as a push (every third day at noon). It's personal when this month's numbers give us something, otherwise a general habit tip.
const GENERAL_TIPS = [
  ["Try a no-spend day this week. Paw prints on your hop calendar mark each one 🐾", "Intenta un día sin gastos esta semana. Las huellas en tu calendario marcan cada uno 🐾", "这周试试零花费的一天吧。蹦跳日历上的爪印会标记每一天 🐾"],
  ["Wait a day before buying anything over $50. If you still want it tomorrow, go for it 🐰", "Espera un día antes de comprar algo de más de $50. Si mañana aún lo quieres, adelante 🐰", "超过 $50 的东西先等一天再买。明天还想要，就买吧 🐰"],
  ["Set a budget for your biggest category. I'll give you a heads-up at 80% 🥕", "Pon un presupuesto a tu categoría más grande. Te aviso al llegar al 80% 🥕", "给花得最多的类别设个预算。到 80% 时我会提醒你 🥕"],
  ["Give your savings goal a fun name. People save more for a \"Beach trip\" than for \"Savings\" 🍯", "Ponle un nombre divertido a tu meta. Se ahorra más para un \"Viaje a la playa\" que para \"Ahorros\" 🍯", "给储蓄目标起个有趣的名字。人们为“海边旅行”存的钱比为“储蓄”多 🍯"],
  ["Planning meals on Sunday is one of the easiest ways to spend less on food 🥕", "Planear las comidas el domingo es una de las formas más fáciles de gastar menos en comida 🥕", "周日提前规划一周饮食，是减少餐饮开销最简单的方法之一 🥕"],
  ["Add your bills once in Plan, and I'll remind you before each one is due 🐰", "Agrega tus facturas una vez en Plan y te recordaré antes de cada vencimiento 🐰", "在计划里添加一次账单，每次到期前我都会提醒你 🐰"],
  ["Check Together once a week, so nobody's surprised by who owes who 💞", "Revisa Juntos una vez por semana para que nadie se sorprenda con quién le debe a quién 💞", "每周看一次“一起”，谁欠谁就不会有惊喜了 💞"],
  ["Paying yourself first works: move a little into a honey jar right after payday 🍯", "Págate primero: pasa un poco a un frasco de miel justo después del día de pago 🍯", "先存后花很有效：发薪后马上往蜂蜜罐里存一点 🍯"],
  ["Small daily treats add up. $5 a day is about $150 a month ☕", "Los pequeños gustos diarios suman. $5 al día son unos $150 al mes ☕", "每天的小犒劳会积少成多。每天 $5 大约就是每月 $150 ☕"],
];
async function bunTip(env, p, L) {
  const li = { en: 0, es: 1, zh: 2 }[PUSH_TEXT[p.lang] ? p.lang : "en"];
  try {
    const first = L.date.slice(0, 8) + "01";
    const r = await env.DB.prepare("SELECT COUNT(*) n, COALESCE(SUM(amount_cents),0) s FROM entries WHERE nest_id = ? AND type = 'expense' AND category = 'food' AND date >= ? AND date <= ? AND (member_id = ? OR shared = 1)").bind(p.nest_id, first, L.date, p.id).first();
    if (r && r.n >= 4) {
      const save = Math.round(r.s / r.n * 2);
      return [`You've logged eating out ${r.n} times this month (${money(r.s)}). Skipping two could save about ${money(save)} 🐰`,
        `Has registrado comida fuera ${r.n} veces este mes (${money(r.s)}). Saltarte dos podría ahorrarte unos ${money(save)} 🐰`,
        `这个月你记了 ${r.n} 次外出就餐（${money(r.s)}）。少吃两次大约能省 ${money(save)} 🐰`][li];
    }
  } catch (e) { console.error("bun tip", e.message); }
  const day = Math.floor(pDay(L.date) / dayMs);
  return GENERAL_TIPS[day % GENERAL_TIPS.length][li];
}
async function nestBillsDue(env, cache, nestId, from, to) {
  if (!cache[nestId]) {
    const [rec, logged] = await env.DB.batch([
      env.DB.prepare("SELECT id, type, label, amount_cents, member_id, shared, freq, anchor_date FROM recurring WHERE nest_id = ? AND type = 'expense'").bind(nestId),
      env.DB.prepare("SELECT recurring_id, occ_date FROM entries WHERE nest_id = ? AND recurring_id IS NOT NULL AND occ_date >= ?").bind(nestId, sDay(Date.now() - 40 * dayMs)),
    ]);
    cache[nestId] = { rec: rec.results, logged: new Set(logged.results.map((l) => l.recurring_id + "|" + l.occ_date)) };
  }
  const c = cache[nestId], out = [];
  for (const r of c.rec) for (const d of occurrencesS(r, from, to)) if (!c.logged.has(r.id + "|" + d)) out.push({ r, d });
  return out.sort((a, b) => a.d.localeCompare(b.d));
}


// On the 1st of the month (9am where each person lives) everyone gets asked whether to carry last month's balance forward.
async function carryNudges(env) {
  const people = (await env.DB.prepare("SELECT u.id, u.tz, u.lang, m.nest_id FROM users u JOIN members m ON m.user_id = u.id").all()).results;
  const cache = {};
  for (const p of people) {
    try {
      const L = localNow(p.tz);
      if (L.hour !== 9 || L.date.slice(8) !== "01") continue;
      const month = L.date.slice(0, 7), key = p.nest_id + "|" + month;
      if (!(key in cache)) {
        const decided = await env.DB.prepare("SELECT 1 FROM month_carry WHERE nest_id = ? AND month = ?").bind(p.nest_id, month).first();
        const mode = (await env.DB.prepare("SELECT carry_mode FROM nests WHERE id = ?").bind(p.nest_id).first())?.carry_mode || "ask";
        if (!decided && mode !== "ask") { cache[key] = null; continue; } // answered by their remembered choice the first time they open the app
        const pb = decided ? null : await monthBalance(env, p.nest_id, prevMonth(month));
        cache[key] = pb && (pb.entries > 0 || pb.carried !== 0) ? pb : null;
      }
      const pb = cache[key];
      if (!pb) continue;
      const data = { amount: Math.abs(pb.cents), neg: pb.cents < 0, from: new Date(+prevMonth(month).slice(0, 4), +prevMonth(month).slice(5) - 1, 1).toLocaleDateString(p.lang === "es" ? "es" : p.lang === "zh" ? "zh-CN" : "en-US", { month: "long" }) };
      await postMessage(env, p.id, p.nest_id, "carry_ask", data, "carry_ask:" + month);
      await sendPush(env, p.id, pushText("carry_ask", data, p.lang));
    } catch (e) { console.error("carry nudge", p.id, e.message); }
  }
}

async function sendReminders(env) {
  const appUrl = (env.APP_URL || "https://honeybun.me").replace(/\/$/, "");
  const people = (await env.DB.prepare(
    `SELECT u.id, u.email, u.name, u.tz, u.lang, u.mail_bills, u.mail_streak, u.mail_weekly, u.last_bill_mail, u.last_streak_mail, u.last_week_mail, u.unsub_token,
            m.nest_id, m.streak, m.last_day, m.week_key, m.week_xp
     FROM users u JOIN members m ON m.user_id = u.id WHERE u.email_verified = 1 AND (u.mail_bills = 1 OR u.mail_streak = 1 OR u.mail_weekly = 1)`
  ).all()).results;
  const nestCache = {};
  const nestBills = (nestId, from, to) => nestBillsDue(env, nestCache, nestId, from, to);
  for (const p of people) {
    try {
      const L = localNow(p.tz), t = mailT(p.lang);
      let token = p.unsub_token;
      const unsub = async (k) => {
        if (!token) { token = randomToken(); await env.DB.prepare("UPDATE users SET unsub_token = ? WHERE id = ?").bind(token, p.id).run(); }
        return `${appUrl}/api/unsubscribe?u=${encodeURIComponent(p.id)}&t=${token}&k=${k}`;
      };
      const send = async (kind, col, subject, heading, intro, rows, button) => {
        const u = await unsub(kind);
        await sendEmail(env, p.email, subject, `${intro}\n\n${appUrl}\n\n${t.unsub}: ${u}`,
          mailHtml({ lang: p.lang, heading, intro, rows, button, link: appUrl, appUrl, unsubUrl: u }),
          { "List-Unsubscribe": `<${u}>` });
        await env.DB.prepare(`UPDATE users SET ${col} = ? WHERE id = ?`).bind(L.date, p.id).run();
      };
      // 9am: bills due in the next 3 days
      if (p.mail_bills && L.hour === 9 && p.last_bill_mail !== L.date) {
        const due = (await nestBills(p.nest_id, L.date, sDay(pDay(L.date) + 3 * dayMs))).filter((x) => x.r.shared || x.r.member_id === p.id);
        if (due.length) await send("bills", "last_bill_mail", t.billsSubj(due.length), t.billsHead, t.billsBody(p.name),
          mailRows(due.slice(0, 8).map((x) => [`${x.r.label} · ${t.due} ${x.d.slice(5).replace("-", "/")}`, money(x.r.amount_cents)])), t.open);
      }
      // 7pm: streak about to break
      if (p.mail_streak && L.hour === 19 && p.last_streak_mail !== L.date && p.streak >= 2 && p.last_day === sDay(pDay(L.date) - dayMs)) {
        await send("streak", "last_streak_mail", t.streakSubj(p.streak), t.streakHead, t.streakBody(p.name, p.streak), "", t.streakBtn);
      }
      // Sunday 6pm: weekly recap
      if (p.mail_weekly && L.hour === 18 && L.weekday === "Sun" && p.last_week_mail !== L.date) {
        const from = sDay(pDay(L.date) - 6 * dayMs);
        const rows = (await env.DB.prepare("SELECT category, SUM(amount_cents) AS c FROM entries WHERE nest_id = ? AND type = 'expense' AND date >= ? AND date <= ? AND (private = 0 OR member_id = ?) GROUP BY category ORDER BY c DESC")
          .bind(p.nest_id, from, L.date, p.id).all()).results;
        const spent = rows.reduce((s, r) => s + r.c, 0);
        if (spent > 0 || p.week_xp > 0) {
          const names = { home: "🏠", groc: "🛒", food: "🍜", date: "💕", bills: "💡", subs: "📺", car: "🚗", fun: "🎁", pets: "🐾", debt: "💳", other: "✨" };
          const streakNow = p.last_day === L.date || p.last_day === sDay(pDay(L.date) - dayMs) ? p.streak : 0;
          await send("weekly", "last_week_mail", t.weekSubj, t.weekHead, t.weekBody(p.name), mailRows([
            [t.spent, money(spent)],
            ...(rows[0] ? [[t.top, `${names[rows[0].category] || "✨"} ${money(rows[0].c)}`]] : []),
            [t.carrots, `🥕 ${p.week_key === from ? p.week_xp : 0}`],
            [t.streak, `🐾 ${t.days(streakNow)}`],
          ]), t.open);
        }
      }
    } catch (e) { console.error("reminder failed", p.id, e.message); }
  }
}
