// Replays the exact requests the native SwiftUI client (HBAPI) makes against a running Honeybun worker
// (default: `npx wrangler dev --local --port 8788`) and checks the answers match what the Swift models expect.
// Also writes fixtures/nest.json, a real /api/nest response that CI decodes with the Swift models.
import { writeFileSync, mkdirSync } from "node:fs";
const BASE = process.env.HB_BASE || "http://localhost:8788";
const ORIGIN = new URL(BASE).origin;           // the app sends Origin: https://honeybun.me; locally this is the local origin
let cookie = "";
const out = []; const ok = (n, v, extra = "") => { out.push((v ? "PASS " : "FAIL ") + n + (extra && !v ? "  → " + extra : "")); if (!v) process.exitCode = 1; };

async function call(path, method = "GET", body, { origin = true, withCookie = true } = {}) {
  const h = { accept: "application/json" };
  if (origin) h.origin = ORIGIN;
  if (withCookie && cookie) h.cookie = cookie;
  let payload;
  if (body !== undefined || method !== "GET") { h["content-type"] = "application/json"; payload = JSON.stringify(body ?? {}); }
  const r = await fetch(BASE + path, { method, headers: h, body: payload });
  const sc = r.headers.get("set-cookie");
  if (sc) cookie = sc.split(",").map((c) => c.split(";")[0].trim()).filter((c) => c.startsWith("__Host-hb=")).join("; ") || cookie;
  let j = null; try { j = await r.json(); } catch {}
  return { status: r.status, json: j };
}
const dd = (n) => new Date(Date.now() + n * 864e5).toISOString().slice(0, 10);
const month = new Date().toISOString().slice(0, 7);

// --- 1. a signed-in web session (what the Capacitor web view holds)
const u = "ct" + Date.now() % 1e7;
let r = await call("/api/signup", "POST", { name: "Contract Test", username: u, password: "Passw0rd!xyzzy" });
ok("web session created (cookie __Host-hb set)", cookie.startsWith("__Host-hb="), JSON.stringify(r));
await call("/api/nests", "POST", { name: "Us", kind: "couple" });
await call("/api/setup/done", "POST", {});

// --- 2. auth behaviour the Swift client relies on
r = await call("/api/nest?month=" + month, "GET", undefined, { withCookie: false });
ok("no cookie → 401 (client maps this to 'signed out')", r.status === 401, "got " + r.status);
r = await call("/api/entries", "POST", { type: "expense", amount: 1, label: "x" }, { origin: false });
ok("mutation without Origin header → 403 (so the client must send Origin)", r.status === 403, "got " + r.status);
r = await call("/api/me");
const me = r.json?.user;
ok("/api/me with the cookie returns the user", !!me?.id && r.status === 200);

// --- 3. /api/nest shape = Swift models
r = await call("/api/nest?month=" + month);
const n = r.json;
ok("/api/nest loads authenticated data (200)", r.status === 200 && !!n?.nest?.id);
const has = (o, k, t) => o && k in o && (t === "any" || typeof o[k] === t);
ok("snapshot: me{id,name}, nest{id,name}, members/entries/recurring/logged/goals arrays",
  has(n.me, "id", "string") && has(n.nest, "id", "string") && has(n.nest, "name", "string") && ["members", "entries", "recurring", "logged", "goals"].every((k) => Array.isArray(n[k])));
ok("members have id+name", n.members.length === 1 && has(n.members[0], "id", "string") && has(n.members[0], "name", "string"));
const mid = me.id;

// --- 4. create expense + income exactly like the Swift draft JSON
const expense = { type: "expense", amount: 120.5, label: "Native dinner", date: dd(0), member_id: mid, shared: false, private: false, category: "food" };
r = await call("/api/entries", "POST", expense);
ok("POST /api/entries expense → 201 {ok,id}", r.status === 201 && r.json?.ok && typeof r.json.id === "string", JSON.stringify(r));
const expId = r.json?.id;
r = await call("/api/entries", "POST", { type: "income", amount: 3000, label: "Native pay", date: dd(0), member_id: mid, shared: false, private: false });
ok("POST /api/entries income (no category) → 201", r.status === 201, JSON.stringify(r));
const incId = r.json?.id;

r = await call("/api/nest?month=" + month);
let ex = r.json.entries.find((e) => e.id === expId), inc = r.json.entries.find((e) => e.id === incId);
ok("expense persisted: 12050 cents, category food", ex?.amount_cents === 12050 && ex.category === "food");
ok("income persisted: 300000 cents, category null (Swift: optional)", inc?.amount_cents === 300000 && inc.category === null);
ok("totals Home/Money will show: income 3000, spent 120.50", r.json.entries.filter((e) => e.type === "income").reduce((a, e) => a + e.amount_cents, 0) === 300000 && r.json.entries.filter((e) => e.type === "expense").reduce((a, e) => a + e.amount_cents, 0) === 12050);
writeFileSync("/tmp/nest-before.json", JSON.stringify(r.json));

// --- 5. edit
r = await call("/api/entries/" + expId, "PATCH", { ...expense, amount: 80, label: "Native dinner v2", category: "groc" });
ok("PATCH /api/entries/:id → 200 {ok}", r.status === 200 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
ex = r.json.entries.find((e) => e.id === expId);
ok("edit persisted (8000 cents, groc, new label)", ex?.amount_cents === 8000 && ex.category === "groc" && ex.label === "Native dinner v2");

// --- 6. recurring: create, appears in recurring[], edit, mark paid (log), delete
r = await call("/api/recurring", "POST", { type: "expense", amount: 15.99, label: "Streaming", freq: "monthly", date: dd(5), member_id: mid, shared: false, category: "subs" });
ok("POST /api/recurring → 201 {id}", r.status === 201 && typeof r.json?.id === "string", JSON.stringify(r));
const recId = r.json?.id;
r = await call("/api/nest?month=" + month);
const rec = r.json.recurring.find((x) => x.id === recId);
ok("recurring[] has it (Coming Up source): freq monthly, anchor_date, cents", rec?.freq === "monthly" && rec.anchor_date === dd(5) && rec.amount_cents === 1599);
r = await call("/api/recurring/" + recId, "PATCH", { type: "expense", amount: 17.99, label: "Streaming+", freq: "monthly", date: dd(5), member_id: mid, shared: false, category: "subs" });
ok("PATCH /api/recurring/:id → 200", r.status === 200 && r.json?.ok, JSON.stringify(r));
r = await call(`/api/recurring/${recId}/log`, "POST", { occ_date: dd(5) });
ok("POST /api/recurring/:id/log (mark paid) → 201", r.status === 201 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + dd(5).slice(0, 7));
ok("logged[] now lists that occurrence (so Coming Up skips it)", r.json.logged.some((l) => l.recurring_id === recId && l.occ_date === dd(5)));
ok("and a real expense entry was created for it", r.json.entries.some((e) => e.recurring_id === recId && e.amount_cents === 1799));
writeFileSync("/tmp/nest-after.json", JSON.stringify(r.json));

// keep one unlogged bill + a goal so the CI decode fixture contains Coming Up data
await call("/api/recurring", "POST", { type: "expense", amount: 42.34, label: "Phone bill", freq: "monthly", date: dd(3), member_id: mid, shared: false, category: "bills" });
await call("/api/recurring", "POST", { type: "income", amount: 1200, label: "Side payday", freq: "biweekly", date: dd(9), member_id: mid, shared: false });
await call("/api/goals", "POST", { name: "Trip to Japan", target: 3000, emoji: "✈️" });
r = await call("/api/nest?month=" + month);
mkdirSync(new URL("./fixtures/", import.meta.url), { recursive: true });
writeFileSync(new URL("./fixtures/nest.json", import.meta.url), JSON.stringify({ today: dd(0), snapshot: r.json }, null, 1));

// --- 7. delete
r = await call("/api/entries/" + expId, "DELETE");
ok("DELETE /api/entries/:id → 200", r.status === 200 && r.json?.ok);
r = await call("/api/nest?month=" + month);
ok("deleted: gone from entries, spent back to 0", !r.json.entries.some((e) => e.id === expId) && r.json.entries.filter((e) => e.type === "expense").length === 1 /* only the marked-paid bill */);
r = await call("/api/recurring/" + recId, "DELETE");
ok("DELETE /api/recurring/:id → 200", r.status === 200);

// --- 8. savings goals (native Goals tab)
r = await call("/api/goals", "POST", { name: "Vacation Fund", target: 1000, emoji: "✈️" });
ok("POST /api/goals → 201 {id}", r.status === 201 && typeof r.json?.id === "string", JSON.stringify(r));
const gid = r.json?.id;
r = await call("/api/goals", "POST", { name: "   ", target: 50, emoji: "🍯" });
ok("goal with an empty name is rejected (400)", r.status === 400, "got " + r.status);
r = await call("/api/goals", "POST", { name: "Zero", target: 0, emoji: "🍯" });
ok("goal with a $0 target is rejected (400)", r.status === 400, "got " + r.status);
r = await call("/api/goals", "POST", { name: "x".repeat(60), target: 10, emoji: "not-an-emoji" });
const longId = r.json?.id;
r = await call("/api/nest?month=" + month);
const longGoal = r.json.goals.find((g) => g.id === longId);
ok("name is cut to 30 characters and an unknown emoji falls back to the first", longGoal?.name.length === 30 && longGoal.emoji === "🍯");
await call("/api/goals/" + longId, "DELETE");
r = await call("/api/jar", "POST", { goal_id: gid, amount: 120, direction: "in" });
ok("POST /api/jar in → 200 {ok}", r.status === 200 && r.json?.ok, JSON.stringify(r));
await call("/api/jar", "POST", { goal_id: gid, amount: 300.5, direction: "in" });
r = await call("/api/jar", "POST", { goal_id: gid, amount: 20, direction: "out" });
ok("POST /api/jar out → 200 {ok}", r.status === 200 && r.json?.ok, JSON.stringify(r));
r = await call("/api/jar", "POST", { goal_id: gid, amount: 99999, direction: "out" });
ok("taking out more than saved is refused with a message (400)", r.status === 400 && /can't take out more/i.test(r.json?.error || ""), JSON.stringify(r));
r = await call("/api/nest?month=" + month);
let g = r.json.goals.find((x) => x.id === gid);
ok("goal saved = 120 + 300.50 - 20 = 40050 cents; shape has id,name,emoji,target_cents,saved_cents", g?.saved_cents === 40050 && g.target_cents === 100000 && g.emoji === "✈️" && g.name === "Vacation Fund");
const moves = r.json.jar.filter((j) => j.goal_id === gid);
ok("jar[] lists the 3 moves with signed cents, member_id, created_at (seconds)", moves.length === 3 && moves.some((m) => m.amount_cents === -2000) && moves.every((m) => m.member_id === mid && typeof m.created_at === "number"));
const out20 = moves.find((m) => m.amount_cents === -2000);
r = await call("/api/jar/" + out20.id, "DELETE");
ok("DELETE /api/jar/:id (undo a move) → 200", r.status === 200 && r.json?.ok);
r = await call("/api/nest?month=" + month);
ok("undoing the take-out puts the 20 back (42050)", r.json.goals.find((x) => x.id === gid)?.saved_cents === 42050);
r = await call("/api/goals/" + gid, "PATCH", { name: "Trip to Japan", target: 2000, emoji: "🏠" });
ok("PATCH /api/goals/:id → 200", r.status === 200 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
g = r.json.goals.find((x) => x.id === gid);
ok("edit changed name/target/emoji and kept the savings", g?.name === "Trip to Japan" && g.target_cents === 200000 && g.emoji === "🏠" && g.saved_cents === 42050);
writeFileSync(new URL("./fixtures/nest-goals.json", import.meta.url), JSON.stringify({ today: dd(0), snapshot: r.json }, null, 1));
r = await call("/api/goals/" + gid, "DELETE");
ok("DELETE /api/goals/:id → 200", r.status === 200 && r.json?.ok);
r = await call("/api/nest?month=" + month);
ok("deleting a goal removes it and its history", !r.json.goals.some((x) => x.id === gid) && !r.json.jar.some((j) => j.goal_id === gid));

console.log(out.join("\n"));
