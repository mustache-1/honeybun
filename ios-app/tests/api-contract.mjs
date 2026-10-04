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


// --- 9. Together tab: household, shared shopping list, fair share balances, paying each other back
const cookieA = cookie;
r = await call("/api/nest?month=" + month);
const nestA = r.json;
ok("solo budget: nest has invite_code + kind, one member, balances for me = 0, settlements []",
  typeof nestA.nest.invite_code === "string" && nestA.nest.invite_code.length >= 6 && nestA.nest.kind === "couple" && nestA.members.length === 1 && nestA.balances?.[mid] === 0 && Array.isArray(nestA.settlements) && nestA.settlements.length === 0);

// shared shopping list (works on your own)
r = await call("/api/shopping", "POST", { label: "Oat milk" });
ok("POST /api/shopping → 201 {id}", r.status === 201 && typeof r.json?.id === "string", JSON.stringify(r));
const shopA = r.json?.id;
r = await call("/api/shopping", "POST", { label: "   " });
ok("blank shopping item rejected (400)", r.status === 400, "got " + r.status);
await call("/api/shopping", "POST", { label: "Eggs" });
r = await call("/api/shopping");
ok("GET /api/shopping → {items:[{id,label,added_by,done,done_by}]}", r.status === 200 && Array.isArray(r.json?.items) && r.json.items.length === 2 && r.json.items.every((i) => has(i, "id", "string") && has(i, "label", "string") && typeof i.done === "boolean") && r.json.items.some((i) => i.added_by === mid));
r = await call("/api/shopping/" + shopA, "PATCH", { done: true });
ok("tick off an item → 200", r.status === 200 && r.json?.ok);
r = await call("/api/shopping");
ok("ticked item is done with done_by = me, and sorts below the open ones", r.json.items.find((i) => i.id === shopA)?.done === true && r.json.items.find((i) => i.id === shopA)?.done_by === mid && r.json.items[r.json.items.length - 1].id === shopA);
r = await call("/api/shopping/" + shopA, "PATCH", { label: "Oat milk (barista)" });
ok("rename an item keeps it ticked", r.status === 200 && (await call("/api/shopping")).json.items.find((i) => i.id === shopA)?.label === "Oat milk (barista)" && (await call("/api/shopping")).json.items.find((i) => i.id === shopA)?.done === true);
r = await call("/api/shopping/checkout", "POST", { amount: 23.4, date: dd(0) });
ok("Done shopping: logs groceries + clears ticked items (201)", r.status === 201 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
ok("checkout made a 2340-cent groceries expense", r.json.entries.some((e) => e.category === "groc" && e.amount_cents === 2340 && e.type === "expense"));
r = await call("/api/shopping");
ok("ticked items were cleared, the open one stayed", r.json.items.length === 1 && r.json.items[0].label === "Eggs");
const eggs = r.json.items[0].id;
r = await call("/api/shopping/" + eggs, "DELETE");
ok("delete an item → 200", r.status === 200 && (await call("/api/shopping")).json.items.length === 0);
await call("/api/shopping", "POST", { label: "A" }); await call("/api/shopping", "POST", { label: "B" });
const ls = (await call("/api/shopping")).json.items;
await call("/api/shopping/" + ls[0].id, "PATCH", { done: true });
r = await call("/api/shopping/clear", "POST");
ok("clear checked items → only open ones remain", r.status === 200 && (await call("/api/shopping")).json.items.length === 1);
await call("/api/shopping/" + (await call("/api/shopping")).json.items[0].id, "DELETE");

// invite code: regenerate
const oldCode = nestA.nest.invite_code;
r = await call("/api/nest/invite", "POST");
ok("POST /api/nest/invite → new invite_code", r.status === 200 && typeof r.json?.invite_code === "string" && r.json.invite_code !== oldCode, JSON.stringify(r));
const code = r.json.invite_code;

// a second person signs up and joins with the code
cookie = "";
const u2 = "ct" + ((Date.now() + 7) % 1e7);
r = await call("/api/signup", "POST", { name: "Second Person", username: u2, password: "Passw0rd!xyzzy" });
const cookieB = cookie;
r = await call("/api/nests/join", "POST", { code: oldCode });
ok("the OLD invite code no longer works (404)", r.status === 404, "got " + r.status);
r = await call("/api/nests/join", "POST", { code: code.toLowerCase() });
ok("join with the new code (any case) → 200 {nest_id}", r.status === 200 && r.json?.ok && typeof r.json.nest_id === "string", JSON.stringify(r));
const meB = (await call("/api/me")).json.user;
cookie = cookieA;
r = await call("/api/nest?month=" + month);
const duo = r.json;
const mB = duo.members.find((m) => m.id === meB.id), mA = duo.members.find((m) => m.id === mid);
ok("household now has 2 members with different buddy + colour", duo.members.length === 2 && mA && mB && mA.emoji !== mB.emoji && mA.color !== mB.color && has(mB, "name", "string"));
ok("with two people: balances has both ids at 0", duo.balances[mid] === 0 && duo.balances[meB.id] === 0);

// a shared expense splits equally → the balance shows who owes whom
r = await call("/api/entries", "POST", { type: "expense", amount: 100, label: "Shared dinner", date: dd(0), member_id: mid, shared: true, private: false, category: "food" });
ok("shared expense accepted", r.status === 201, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
ok("fair share: I am owed 5000 cents, they owe 5000", r.json.balances[mid] === 5000 && r.json.balances[meB.id] === -5000, JSON.stringify(r.json.balances));
r = await call("/api/settlements", "POST", { from_id: mid, to_id: mid, amount: 5, date: dd(0) });
ok("settling with yourself is refused (400)", r.status === 400, "got " + r.status);
r = await call("/api/settlements", "POST", { from_id: meB.id, to_id: mid, amount: 0, date: dd(0) });
ok("settling $0 is refused (400)", r.status === 400, "got " + r.status);
r = await call("/api/settlements", "POST", { from_id: meB.id, to_id: mid, amount: 20, date: dd(0) });
ok("POST /api/settlements (they paid me $20) → 201", r.status === 201 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
const st = r.json.settlements[0];
ok("settlement listed {id,from_id,to_id,amount_cents,date} and the balance dropped to 3000 / −3000",
  r.json.settlements.length === 1 && st.from_id === meB.id && st.to_id === mid && st.amount_cents === 2000 && st.date === dd(0) && r.json.balances[mid] === 3000 && r.json.balances[meB.id] === -3000);
writeFileSync(new URL("./fixtures/nest-together.json", import.meta.url), JSON.stringify({ today: dd(0), me: mid, other: meB.id, snapshot: r.json }, null, 1));
r = await call("/api/settlements/" + st.id, "DELETE");
ok("DELETE /api/settlements/:id → 200 and the balance goes back to 5000", r.status === 200 && (await call("/api/nest?month=" + month)).json.balances[mid] === 5000);

// joint account + budget type + name
r = await call("/api/nest", "PATCH", { joint: true });
ok("joint account on (couple, 2 people) → nest.joint = 1", r.status === 200 && (await call("/api/nest?month=" + month)).json.nest.joint === 1);
r = await call("/api/nest", "PATCH", { kind: "family" });
r = await call("/api/nest", "PATCH", { joint: true });
ok("joint account is refused for a family budget (400)", r.status === 400 && /couples/i.test(r.json?.error || ""), JSON.stringify(r));
r = await call("/api/nest", "PATCH", { kind: "couple" });
r = await call("/api/nest", "PATCH", { joint: false });
ok("joint account off → nest.joint = 0", r.status === 200 && (await call("/api/nest?month=" + month)).json.nest.joint === 0);
r = await call("/api/nest", "PATCH", { kind: "nonsense" });
ok("unknown budget type refused (400)", r.status === 400, "got " + r.status);
r = await call("/api/nest", "PATCH", { name: "Our Hive" });
ok("rename the budget", r.status === 200 && (await call("/api/nest?month=" + month)).json.nest.name === "Our Hive");

// edit yourself
r = await call("/api/me", "PATCH", { name: "Renamed", emoji: "🐻", color: "#E4EDFF" });
ok("PATCH /api/me name+buddy+colour → 200", r.status === 200 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
const mA2 = r.json.members.find((m) => m.id === mid);
ok("members[] shows the new name, buddy and colour", mA2?.name === "Renamed" && mA2.emoji === "🐻" && mA2.color === "#E4EDFF");
r = await call("/api/me", "PATCH", { emoji: "🤖" });
ok("a buddy that doesn't exist is refused (400)", r.status === 400, "got " + r.status);
r = await call("/api/me", "PATCH", { name: "   " });
ok("an empty name is refused (400)", r.status === 400, "got " + r.status);

// search everything
r = await call("/api/search?" + new URLSearchParams({ q: "dinner", type: "expense", member: "" }));
ok("GET /api/search → {entries:[...]} with the shared dinner", r.status === 200 && Array.isArray(r.json?.entries) && r.json.entries.some((e) => e.label === "Shared dinner" && e.shared === 1));
r = await call("/api/search?" + new URLSearchParams({ q: "zzzz-nothing", type: "", member: "" }));
ok("search with no match → empty list", r.status === 200 && r.json.entries.length === 0);


// --- 10. Inbox: Bun's messages, read/unread, the buttons' backend calls, carry-over question
cookie = cookieA;
r = await call("/api/recurring", "POST", { type: "expense", amount: 31.5, label: "Inbox Bill", freq: "monthly", date: dd(0), member_id: mid, shared: false, category: "bills" });
const inboxRec = r.json?.id;
r = await call("/api/recurring", "POST", { type: "income", amount: 800, label: "Inbox Payday", freq: "monthly", date: dd(0), member_id: mid, shared: false });
const inboxPay = r.json?.id;
// something from last month so the new-month "carry it over?" question exists
const lastMonth = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 1, 15)).toISOString().slice(0, 10);
r = await call("/api/entries", "POST", { type: "income", amount: 500, label: "Last month pay", date: lastMonth, member_id: mid, shared: false, private: false });
ok("an entry from last month was accepted", r.status === 201, JSON.stringify(r));
r = await call("/api/inbox");
const inbox1 = r.json;
ok("GET /api/inbox → {messages:[{id,kind,data,created_at,read_at}]}", r.status === 200 && Array.isArray(inbox1?.messages) && inbox1.messages.length > 0 && inbox1.messages.every((m) => has(m, "id", "string") && has(m, "kind", "string") && typeof m.data === "object" && typeof m.created_at === "number"));
ok("real events produce messages: level-ups and 'joined' from the household (welcome only appears if the inbox was empty first)", inbox1.messages.some((m) => m.kind === "level" && typeof m.data.level === "number") && inbox1.messages.some((m) => m.kind === "joined" && typeof m.data.name === "string"));
const billMsg = inbox1.messages.find((m) => m.data?.rid === inboxRec), payMsg = inbox1.messages.find((m) => m.data?.rid === inboxPay);
ok("a bill due today produces a bill message with rid, occ, label, amount (kind bill_today / bill_late / bill_soon)", !!billMsg && ["bill_today", "bill_late", "bill_soon"].includes(billMsg.kind) && /^\d{4}-\d{2}-\d{2}$/.test(billMsg.data.occ) && billMsg.data.label === "Inbox Bill" && billMsg.data.amount === 3150, JSON.stringify(billMsg));
ok("a payday produces a payday message", payMsg?.kind === "payday" && payMsg.data.amount === 80000, JSON.stringify(payMsg));
ok("new messages arrive unread (read_at null)", inbox1.messages.every((m) => m.read_at === null));
r = await call("/api/nest?month=" + month);
const unreadBefore = r.json.inbox?.unread;
ok("/api/nest carries the unread count for the badge", typeof unreadBefore === "number" && unreadBefore >= inbox1.messages.length - 0, JSON.stringify(r.json.inbox));
ok("/api/nest has a carry_pending question {from,amount_cents} for this month", r.json.carry_pending?.from === lastMonth.slice(0, 7) && r.json.carry_pending?.amount_cents === 50000, JSON.stringify(r.json.carry_pending));
// "Paid" on the bill message
r = await call(`/api/recurring/${inboxRec}/log`, "POST", { occ_date: billMsg.data.occ });
ok("Paid on a bill message → POST /api/recurring/:id/log → 201", r.status === 201 && r.json?.ok, JSON.stringify(r));
r = await call("/api/nest?month=" + billMsg.data.occ.slice(0, 7));
ok("the occurrence is now in logged[] (so the message shows 'Paid ✓') and an expense of 3150 exists", r.json.logged.some((l) => l.recurring_id === inboxRec && l.occ_date === billMsg.data.occ) && r.json.entries.some((e) => e.recurring_id === inboxRec && e.amount_cents === 3150));
r = await call(`/api/recurring/${inboxRec}/log`, "POST", { occ_date: billMsg.data.occ });
ok("tapping Paid twice does not double-log (200 already)", r.status === 200 && r.json?.already === true || (await call("/api/nest?month=" + billMsg.data.occ.slice(0, 7))).json.entries.filter((e) => e.recurring_id === inboxRec).length === 1, JSON.stringify(r));
// opening the inbox marks everything read
r = await call("/api/inbox/read", "POST");
ok("POST /api/inbox/read → 200", r.status === 200 && r.json?.ok);
r = await call("/api/inbox");
ok("every message is now read (read_at set)", r.json.messages.length > 0 && r.json.messages.every((m) => typeof m.read_at === "number"));
ok("and the badge count is 0", (await call("/api/nest?month=" + month)).json.inbox?.unread === 0);
writeFileSync(new URL("./fixtures/inbox.json", import.meta.url), JSON.stringify({ today: dd(0), recurring: [inboxRec, inboxPay], messages: r.json.messages }, null, 1));
// carry over decision
r = await call("/api/carry", "POST", { month, accept: true, change: false, remember: false });
ok("Carry it over → POST /api/carry → 200 {accepted, amount_cents 50000}", r.status === 200 && r.json?.ok && r.json.accepted === true && r.json.amount_cents === 50000, JSON.stringify(r));
r = await call("/api/nest?month=" + month);
ok("carry_in is set and the question is gone", r.json.carry_in?.accepted === true && r.json.carry_in?.amount_cents === 50000 && r.json.carry_pending === null, JSON.stringify([r.json.carry_in, r.json.carry_pending]));
r = await call("/api/carry", "POST", { month, accept: false, change: false, remember: false });
ok("deciding again without 'change' keeps the first choice (already)", r.status === 200 && r.json?.already === true, JSON.stringify(r));

console.log(out.join("\n"));
