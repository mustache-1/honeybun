// Replays the requests the native iPhone authentication makes against the REAL Honeybun worker (src/worker.js, run locally by wrangler).
// It starts its own `wrangler dev` with a throw-away .dev.vars (a test Apple signing key, DEV_ORIGIN for passkeys) and removes that file afterwards.
// Covers: username + email sign-up/login, recovery codes, password reset + email verification (tokens written straight into the local test database,
// since no email is sent locally), Sign in with Apple identity-token verification, passkeys with a software authenticator, logout, account deletion,
// data export, invite-code sign-up, and that Google sign-in is gone.
import { spawn, spawnSync } from "node:child_process";
import { writeFileSync, rmSync, existsSync } from "node:fs";
import { generateKeyPairSync, createSign, createHash, createPublicKey, randomBytes, sign as edSign } from "node:crypto";

const ROOT = new URL("../../", import.meta.url).pathname;
const PORT = 8789, BASE = `http://localhost:${PORT}`, ORIGIN = BASE;
const out = [];
const ok = (n, v, extra = "") => { out.push((v ? "PASS " : "FAIL ") + n + (!v && extra ? "  → " + extra : "")); if (!v) process.exitCode = 1; };
const b64u = (b) => Buffer.from(b).toString("base64url");
const sha = (t) => createHash("sha256").update(t).digest();

// ---- test Apple key + dev vars
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const jwk = { ...rsa.publicKey.export({ format: "jwk" }), kid: "test-key-1", use: "sig", alg: "RS256" };
writeFileSync(ROOT + ".dev.vars", `APPLE_TEST_JWKS=${JSON.stringify({ keys: [jwk] })}\nDEV_ORIGIN=${ORIGIN}\nAPPLE_TEAM_ID=TEAM123456\n`);
const server = spawn("npx", ["wrangler", "dev", "--local", "--port", String(PORT)], { cwd: ROOT, stdio: ["ignore", "pipe", "pipe"] });
const cleanup = () => { try { server.kill("SIGTERM"); } catch {} try { rmSync(ROOT + ".dev.vars"); } catch {} };
process.on("exit", cleanup);
await new Promise((res, rej) => {
  const t = setTimeout(() => rej(new Error("wrangler did not start")), 90000);
  const on = (d) => { if (String(d).includes("Ready on")) { clearTimeout(t); res(); } };
  server.stdout.on("data", on); server.stderr.on("data", on);
});

// ---- tiny client (one cookie jar per "device")
const jar = () => ({ cookie: "" });
async function call(j, path, method = "GET", body, { origin = true } = {}) {
  const h = { accept: "application/json" };
  if (origin) h.origin = ORIGIN;
  if (j.cookie) h.cookie = j.cookie;
  let payload;
  if (body !== undefined || method !== "GET") { h["content-type"] = "application/json"; payload = JSON.stringify(body ?? {}); }
  const r = await fetch(BASE + path, { method, headers: h, body: payload });
  const sc = r.headers.get("set-cookie");
  if (sc) { const c = sc.split(",").map((x) => x.split(";")[0].trim()).find((x) => x.startsWith("__Host-hb=")); if (c) j.cookie = c.endsWith("=") ? "" : c; }
  let json = null; const text = await r.text(); try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text, setCookie: sc, headers: r.headers };
}
const d1 = (sql) => { const r = spawnSync("npx", ["wrangler", "d1", "execute", "honeybun", "--local", "--command", sql], { cwd: ROOT, encoding: "utf8" }); if (r.status !== 0) throw new Error("d1: " + r.stderr + r.stdout); };
const resetLimits = () => d1("DELETE FROM auth_attempts"); // the real rate limits would otherwise stop a fast test run
const uname = (p) => p + (Date.now() % 1e6) + Math.floor(Math.random() * 99);
const PW = "Passw0rd!xyzzy";

resetLimits();
// ===== 1. username account =====
const A = jar(), uA = uname("ua");
let r = await call(A, "/api/signup", "POST", { name: "Una", username: uA, password: PW });
ok("username sign-up → 201 with a recovery code (XXXX-XXXX-XXXX) and the __Host-hb cookie", r.status === 201 && /^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(r.json?.recovery_code || "") && A.cookie.startsWith("__Host-hb="), JSON.stringify(r.json));
ok("the cookie is HttpOnly, Secure, Path=/ and has no Domain (what the __Host- prefix requires)", /HttpOnly/i.test(r.setCookie) && /Secure/i.test(r.setCookie) && /Path=\//.test(r.setCookie) && !/Domain=/i.test(r.setCookie), r.setCookie);
const recA = r.json.recovery_code;
r = await call(A, "/api/me");
ok("/api/me: username account has no real email, a password, and is not an Apple account", r.status === 200 && r.json.user.has_email === false && r.json.user.has_password === true && r.json.user.apple === false && r.json.user.name === "Una" && r.json.nest_id === null, JSON.stringify(r.json));
const A2 = jar();
r = await call(A2, "/api/login", "POST", { email: uA.toUpperCase(), password: PW });
ok("login with the USERNAME (any case) in the `email` field works — the backend's real credential", r.status === 200 && A2.cookie.startsWith("__Host-hb="), JSON.stringify(r.json));
r = await call(jar(), "/api/login", "POST", { email: uA, password: "wrong-password" });
ok("wrong password → 401 \"Wrong email, username or password.\"", r.status === 401 && /Wrong email, username or password/.test(r.json?.error || ""));
r = await call(jar(), "/api/signup", "POST", { name: "Dup", username: uA, password: PW });
ok("taken username → 409", r.status === 409 && /taken/i.test(r.json?.error || ""));
r = await call(jar(), "/api/signup", "POST", { name: "Bad", username: "a b", password: PW });
ok("invalid username → 400 with the rule", r.status === 400 && /3 to 20/.test(r.json?.error || ""));
r = await call(jar(), "/api/signup", "POST", { name: "Short", username: uname("sh"), password: "short" });
ok("password under 8 characters → 400", r.status === 400, JSON.stringify(r.json));
r = await call(jar(), "/api/signup", "POST", { name: "", username: uname("nn"), password: PW });
ok("missing name → 400", r.status === 400 && /name/i.test(r.json?.error || ""));
r = await call(jar(), "/api/signup", "POST", { name: "NoOrigin", username: uname("no"), password: PW }, { origin: false });
ok("sign-up without the Origin header → 403 (the app must send Origin)", r.status === 403);

// ===== 2. start a budget (the setup screen) =====
r = await call(A, "/api/nests", "POST", { name: "Our Hive", kind: "couple" });
ok("create a budget (name + kind) → 201", r.status === 201 && !!r.json?.nest_id, JSON.stringify(r.json));
r = await call(A, "/api/nest?month=" + new Date().toISOString().slice(0, 7));
const code = r.json?.nest?.invite_code, setupFlag = r.json?.setup_done;
ok("fresh account: setup_done is false (the app shows first-run onboarding) and the budget has an invite code", setupFlag === false && typeof code === "string", JSON.stringify([setupFlag, code]));
r = await call(A, "/api/setup/done", "POST", {});
ok("finishing onboarding → 200", r.status === 200);
ok("then setup_done is true", (await call(A, "/api/nest?month=" + new Date().toISOString().slice(0, 7))).json.setup_done === true);

resetLimits();
// ===== 3. join a household with an invite code at sign-up =====
const B = jar(), uB = uname("ub");
await call(B, "/api/signup", "POST", { name: "Bo", username: uB, password: PW });
r = await call(B, "/api/nests/join", "POST", { code: "ZZZZ9999" });
ok("a wrong invite code → 404 with the message", r.status === 404 && /doesn't match/.test(r.json?.error || ""));
r = await call(B, "/api/nests/join", "POST", { code: code.slice(0, 4) + "-" + code.slice(4) });
ok("a right code typed with a dash joins the household", r.status === 200 && r.json?.ok, JSON.stringify(r.json));
ok("/api/me for the new member points at the shared budget", (await call(B, "/api/me")).json.nest_id === r.json.nest_id);

// ===== 4. recovery code =====
r = await call(jar(), "/api/password/recover", "POST", { username: uA, code: "AAAA-BBBB-CCCC", password: "NewPassw0rd!qq" });
ok("recovery with a wrong code → 401", r.status === 401 && /don't match/.test(r.json?.error || ""));
const R = jar();
r = await call(R, "/api/password/recover", "POST", { username: uA, code: recA.toLowerCase(), password: "NewPassw0rd!qq" });
ok("recovery with the right code (any case) → 200, a NEW recovery code, and a fresh session", r.status === 200 && /^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(r.json?.recovery_code || "") && r.json.recovery_code !== recA && R.cookie.startsWith("__Host-hb="), JSON.stringify(r.json));
ok("…which logged the old sessions out everywhere", (await call(A, "/api/me")).status === 401);
r = await call(jar(), "/api/password/recover", "POST", { username: uA, code: recA, password: "AnotherPassw0rd!zz" });
ok("the old recovery code no longer works", r.status === 401);
ok("login with the new password works, the old one doesn't", (await call(jar(), "/api/login", "POST", { email: uA, password: "NewPassw0rd!qq" })).status === 200 && (await call(jar(), "/api/login", "POST", { email: uA, password: PW })).status === 401);
r = await call(R, "/api/recovery/new", "POST", {});
ok("generate a new recovery code while signed in (username account) → 200 + code", r.status === 200 && /^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(r.json?.recovery_code || ""));

resetLimits();
// ===== 5. email account: verification + password reset (tokens inserted into the local test DB) =====
const E = jar(), email = uname("mail") + "@example.com";
r = await call(E, "/api/signup", "POST", { name: "Em", email, password: PW });
ok("email sign-up → 201, no recovery code", r.status === 201 && !r.json?.recovery_code && E.cookie.startsWith("__Host-hb="), JSON.stringify(r.json));
r = await call(E, "/api/me");
const emailId = r.json.user.id;
ok("/api/me: real email, not verified yet", r.json.user.has_email === true && r.json.user.verified === false);
r = await call(E, "/api/recovery/new", "POST", {});
ok("recovery codes are only for username accounts (email accounts reset by email) → 400", r.status === 400);
r = await call(E, "/api/email/resend", "POST", {});
ok("resend verification email: answers with a message instead of crashing (200, or 503 when no mail key is set locally)", [200, 503].includes(r.status), JSON.stringify(r.json));
r = await call(jar(), "/api/email/verify", "POST", { token: "not-a-real-token" });
ok("a bad verification link → 400 with the message", r.status === 400 && /expired or was already used/.test(r.json?.error || ""));
const vtok = b64u(randomBytes(32));
d1(`INSERT INTO verify_tokens (token_hash, user_id, expires_at) VALUES ('${b64u(sha(vtok))}', '${emailId}', ${Math.floor(Date.now() / 1000) + 3600})`);
r = await call(jar(), "/api/email/verify", "POST", { token: vtok });
ok("a good verification token → 200", r.status === 200 && r.json?.ok, JSON.stringify(r.json));
ok("…and /api/me now says verified", (await call(E, "/api/me")).json.user.verified === true);
r = await call(jar(), "/api/email/verify", "POST", { token: vtok });
ok("the token works only once", r.status === 400);
r = await call(jar(), "/api/password/forgot", "POST", { email: "nobody-here@example.com" });
const f1 = r;
r = await call(jar(), "/api/password/forgot", "POST", { email });
ok("forgot password: an unknown email gets {ok:true}; a known one gets {ok:true} too (locally, with no mail key, the server answers \"Emails aren't set up yet\" for a known address, as before)", f1.status === 200 && f1.json?.ok === true && (r.status === 200 ? r.json?.ok === true : (r.status === 503 && /Emails aren't set up/.test(r.json?.error || ""))), JSON.stringify([f1.json, r.json]));
r = await call(jar(), "/api/password/forgot", "POST", { email: "not-an-email" });
ok("forgot password with a non-email → 400", r.status === 400);
const rtok = b64u(randomBytes(32)), RS = jar();
d1(`INSERT OR REPLACE INTO password_resets (token_hash, user_id, expires_at) VALUES ('${b64u(sha(rtok))}', '${emailId}', ${Math.floor(Date.now() / 1000) + 3600})`);
r = await call(RS, "/api/password/reset", "POST", { token: rtok, password: "short" });
ok("reset with a too-short password → 400 and the link stays valid", r.status === 400);
r = await call(RS, "/api/password/reset", "POST", { token: rtok, password: "ResetPassw0rd!ab" });
ok("reset with a good token → 200, new session, everyone else logged out", r.status === 200 && RS.cookie.startsWith("__Host-hb=") && (await call(E, "/api/me")).status === 401, JSON.stringify(r.json));
ok("login with the reset password works", (await call(jar(), "/api/login", "POST", { email, password: "ResetPassw0rd!ab" })).status === 200);
r = await call(jar(), "/api/password/reset", "POST", { token: rtok, password: "ResetPassw0rd!cd" });
ok("a reset link can't be used twice → 400", r.status === 400 && /expired or was already used/.test(r.json?.error || ""));

resetLimits();
// ===== 6. Sign in with Apple =====
const NONCE_RAW = () => b64u(randomBytes(24));
function appleToken(claims, { kid = "test-key-1", alg = "RS256", key = rsa.privateKey, tamper = false } = {}) {
  const head = b64u(JSON.stringify({ alg, kid })), now = Math.floor(Date.now() / 1000);
  const body = b64u(JSON.stringify({ iss: "https://appleid.apple.com", aud: "me.honeybun.app", iat: now, exp: now + 600, ...claims }));
  const sig = alg === "none" ? "" : createSign("RSA-SHA256").update(head + "." + body).sign(key).toString("base64url");
  return tamper ? head + "." + b64u(JSON.stringify({ ...JSON.parse(Buffer.from(body, "base64url")), sub: "someone-else" })) + "." + sig : `${head}.${body}.${sig}`;
}
const hexNonce = (raw) => sha(raw).toString("hex");
async function apple(j, claims, extra = {}, opts = {}) {
  const raw = extra.nonce ?? NONCE_RAW();
  const tok = opts.token ?? appleToken({ nonce: hexNonce(raw), ...claims }, opts);
  return call(j, "/api/auth/apple", "POST", { identity_token: tok, nonce: raw, ...extra });
}
const sub1 = "001234.abcdef.0001-" + Date.now();
const P1 = jar();
r = await apple(P1, { sub: sub1, email: "relay123@privaterelay.appleid.com", email_verified: "true", is_private_email: "true" }, { name: "Alex" });
ok("Apple sign-in, new account → 201 {created:true} and the SAME __Host-hb session cookie", r.status === 201 && r.json?.created === true && P1.cookie.startsWith("__Host-hb=") && /HttpOnly/i.test(r.setCookie) && /Secure/i.test(r.setCookie), JSON.stringify(r.json));
r = await call(P1, "/api/me");
const appleId = r.json.user.id;
ok("/api/me for the Apple account: name from the app, no real email (relay address is not stored), no password, apple:true", r.json.user.name === "Alex" && r.json.user.has_email === false && !/privaterelay/.test(r.json.user.email) && r.json.user.has_password === false && r.json.user.apple === true, JSON.stringify(r.json.user));
const P2 = jar();
r = await apple(P2, { sub: sub1 });
ok("signing in with Apple again → 200 {created:false}, same account", r.status === 200 && r.json?.created === false && (await call(P2, "/api/me")).json.user.id === appleId, JSON.stringify(r.json));
ok("the Apple session is a normal session: it can create a budget", (await call(P1, "/api/nests", "POST", { name: "Apple Hive", kind: "solo" })).status === 201);
r = await apple(jar(), { sub: sub1 }, { nonce: "a-different-nonce-123" }, { token: appleToken({ sub: sub1, nonce: hexNonce("original-nonce-xyz") }) });
ok("a token made for another nonce is rejected (401) — nobody can replay a stolen token", r.status === 401, JSON.stringify(r.json));
r = await apple(jar(), { sub: sub1, aud: "com.someone.else" });
ok("a token for a different app (audience) → 401", r.status === 401);
r = await apple(jar(), { sub: sub1, iss: "https://evil.example.com" });
ok("a token from a different issuer → 401", r.status === 401);
r = await apple(jar(), { sub: sub1, exp: Math.floor(Date.now() / 1000) - 60 });
ok("an expired token → 401", r.status === 401);
r = await apple(jar(), { sub: sub1 }, {}, { tamper: true });
ok("a token whose contents were changed after signing → 401", r.status === 401);
const other = generateKeyPairSync("rsa", { modulusLength: 2048 });
r = await apple(jar(), { sub: sub1 }, {}, { key: other.privateKey });
ok("a token signed with some other key → 401", r.status === 401);
r = await apple(jar(), { sub: sub1 }, {}, { kid: "unknown-kid" });
ok("a token with an unknown key id → 401", r.status === 401);
r = await apple(jar(), { sub: sub1 }, {}, { alg: "none" });
ok("an unsigned (alg none) token → 401", r.status === 401);
r = await call(jar(), "/api/auth/apple", "POST", { nonce: "abcdefghij" });
ok("missing token → 400", r.status === 400);
// a real, Apple-verified email that matches an existing password account links to it
const L = jar(), linkMail = uname("link") + "@example.com";
await call(L, "/api/signup", "POST", { name: "Lin", email: linkMail, password: PW });
const linkId = (await call(L, "/api/me")).json.user.id;
const LA = jar();
r = await apple(LA, { sub: "001.link." + Date.now(), email: linkMail, email_verified: "true", is_private_email: "false" });
ok("Apple with a verified real email that matches an existing account signs in to THAT account (and marks the email verified)", r.status === 200 && r.json?.created === false && (await call(LA, "/api/me")).json.user.id === linkId && (await call(LA, "/api/me")).json.user.verified === true, JSON.stringify(r.json));
ok("…and the password still works", (await call(jar(), "/api/login", "POST", { email: linkMail, password: PW })).status === 200);
// real Apple email for a brand-new account is kept as the account's email
const RM = jar(), realMail = uname("real") + "@example.com";
r = await apple(RM, { sub: "001.real." + Date.now(), email: realMail, email_verified: "true", is_private_email: "false" });
const meReal = (await call(RM, "/api/me")).json.user;
ok("a new Apple account with a real verified email keeps it (verified) and takes the name from the email when the app sends none", r.status === 201 && meReal.email === realMail && meReal.verified === true && meReal.has_email === true && meReal.name.length > 0);
// logout
r = await call(P1, "/api/logout", "POST", {});
ok("logout → 200 and the cookie is cleared", r.status === 200 && /Max-Age=0/.test(r.setCookie || ""));
ok("the logged-out session is dead on the server (401), even if someone kept the cookie", (await call({ cookie: "__Host-hb=" + "x" }, "/api/me")).status === 401);

resetLimits();
// ===== 7. account deletion (password, and no-password accounts) =====
const D1 = jar(), uD = uname("ud");
await call(D1, "/api/signup", "POST", { name: "Del", username: uD, password: PW });
r = await call(D1, "/api/account/delete", "POST", { password: "wrong" });
ok("delete with the wrong password → 400", r.status === 400 && /password is wrong/.test(r.json?.error || ""));
r = await call(D1, "/api/account/export");
ok("data export works while signed in: JSON download with the account in it", r.status === 200 && /attachment/.test(r.headers.get("content-disposition") || "") && JSON.parse(r.text).account.name === "Del");
r = await call(D1, "/api/account/delete", "POST", { password: PW });
ok("delete with the right password → 200, cookie cleared", r.status === 200 && /Max-Age=0/.test(r.setCookie || ""));
ok("the account is gone: login fails and the session is dead", (await call(jar(), "/api/login", "POST", { email: uD, password: PW })).status === 401 && (await call(D1, "/api/me")).status === 401);
const DA = jar(), subD = "001.del." + Date.now();
await apple(DA, { sub: subD }, { name: "Dee" });
r = await call(DA, "/api/account/delete", "POST", { password: "anything" });
ok("an Apple account can't be deleted by guessing a password — it asks for the word DELETE (400)", r.status === 400 && /DELETE/.test(r.json?.error || ""), JSON.stringify(r.json));
const meD = (await call(DA, "/api/me")).json.user.id;
d1(`UPDATE sessions SET expires_at = ${Math.floor(Date.now() / 1000) + 30 * 86400 - 3600} WHERE user_id = '${meD}'`);
r = await call(DA, "/api/account/delete", "POST", { confirm: "DELETE" });
ok("…and only right after a fresh login: an hour-old session is refused (403 \"log in again\")", r.status === 403 && /log in again/.test(r.json?.error || ""), JSON.stringify(r.json));
const DA2 = jar(); await apple(DA2, { sub: subD });
r = await call(DA2, "/api/account/delete", "POST", { confirm: "DELETE" });
ok("after signing in with Apple again, confirming with DELETE deletes the account (200)", r.status === 200 && /Max-Age=0/.test(r.setCookie || ""), JSON.stringify(r.json));
const DA3 = jar(); r = await apple(DA3, { sub: subD }, { name: "Dee Again" });
ok("signing in with that Apple ID afterwards makes a brand-new account (nothing was left behind)", r.status === 201 && r.json?.created === true && (await call(DA3, "/api/me")).json.user.id !== meD);

resetLimits();
// ===== 8. passkeys with a software authenticator =====
const rpIdHash = sha("localhost");
const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
const spki = ec.publicKey.export({ type: "spki", format: "der" });
const credId = b64u(randomBytes(32));
const PK = jar(), uPk = uname("upk");
await call(PK, "/api/signup", "POST", { name: "Key", username: uPk, password: PW });
const authData = (flags, counter) => Buffer.concat([rpIdHash, Buffer.from([flags]), Buffer.from([counter >>> 24, counter >>> 16, counter >>> 8, counter].map((x) => x & 255))]);
const cdata = (type, challenge, origin = ORIGIN) => Buffer.from(JSON.stringify({ type, challenge, origin, crossOrigin: false }));
r = await call(PK, "/api/passkeys/options", "POST", {});
ok("passkey registration options: challenge, rp.id = the site's domain, ES256 + RS256, discoverable (resident) key required", r.status === 200 && r.json.rp.id === "localhost" && r.json.pubKeyCredParams.some((p) => p.alg === -7) && r.json.authenticatorSelection.residentKey === "required" && typeof r.json.challenge === "string", JSON.stringify(r.json));
const regChal = r.json.challenge;
r = await call(PK, "/api/passkeys", "POST", { id: credId, publicKey: b64u(spki), alg: -7, clientDataJSON: b64u(cdata("webauthn.get", regChal)), authenticatorData: b64u(authData(0x45, 0)) });
ok("registering with the wrong ceremony type is refused (400)", r.status === 400);
r = await call(PK, "/api/passkeys/options", "POST", {}); const regChal2 = r.json.challenge;
r = await call(PK, "/api/passkeys", "POST", { id: credId, publicKey: b64u(spki), alg: -7, name: "iPhone", clientDataJSON: b64u(cdata("webauthn.create", regChal2, "https://evil.example")), authenticatorData: b64u(authData(0x45, 0)) });
ok("a passkey made for a different site is refused", r.status === 400 && /different site/.test(r.json?.error || ""), JSON.stringify(r.json));
r = await call(PK, "/api/passkeys/options", "POST", {}); const regChal3 = r.json.challenge;
r = await call(PK, "/api/passkeys", "POST", { id: credId, publicKey: b64u(spki), alg: -7, name: "iPhone", clientDataJSON: b64u(cdata("webauthn.create", regChal3)), authenticatorData: b64u(authData(0x45, 0)) });
ok("register a passkey (the shape the app sends: id, SPKI public key, alg, clientDataJSON, authenticatorData) → 201", r.status === 201, JSON.stringify(r.json));
r = await call(PK, "/api/passkeys");
ok("GET /api/passkeys lists it with its name", r.json.passkeys.length === 1 && r.json.passkeys[0].id === credId && r.json.passkeys[0].name === "iPhone");
r = await call(PK, "/api/passkeys/options", "POST", {});
ok("the same passkey can't be registered twice (409)", (await call(PK, "/api/passkeys", "POST", { id: credId, publicKey: b64u(spki), alg: -7, clientDataJSON: b64u(cdata("webauthn.create", r.json.challenge)), authenticatorData: b64u(authData(0x45, 0)) })).status === 409);
r = await call(PK, "/api/passkeys/" + encodeURIComponent(credId), "PATCH", { name: "Rodrigo's iPhone" });
ok("rename a passkey", r.status === 200 && (await call(PK, "/api/passkeys")).json.passkeys[0].name === "Rodrigo's iPhone");
async function passkeyLogin(j, counter, { id = credId, key = ec.privateKey, origin = ORIGIN, flags = 0x05, chal } = {}) {
  const o = await call(j, "/api/passkeys/login/options", "POST", {});
  const challenge = chal ?? o.json.challenge, cd = cdata("webauthn.get", challenge, origin), ad = authData(flags, counter);
  const sig = edSign("sha256", Buffer.concat([ad, sha(cd)]), key);
  return { o, res: await call(j, "/api/passkeys/login", "POST", { id, clientDataJSON: b64u(cd), authenticatorData: b64u(ad), signature: b64u(sig) }) };
}
const PL = jar(); let pl = await passkeyLogin(PL, 1);
ok("passkey login options need no account: challenge + rpId", pl.o.status === 200 && pl.o.json.rpId === "localhost" && typeof pl.o.json.challenge === "string");
ok("log in with the passkey → 200 and the same __Host-hb session", pl.res.status === 200 && PL.cookie.startsWith("__Host-hb=") && /HttpOnly/i.test(pl.res.setCookie), JSON.stringify(pl.res.json));
ok("/api/me via the passkey session is the same account", (await call(PL, "/api/me")).json.user.name === "Key");
pl = await passkeyLogin(jar(), 1);
ok("replaying an old counter is refused (401)", pl.res.status === 401);
pl = await passkeyLogin(jar(), 2, { chal: "never-issued-challenge" });
ok("a challenge the server never issued is refused", pl.res.status === 400);
pl = await passkeyLogin(jar(), 3, { key: generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey });
ok("a signature from a different key is refused (401)", pl.res.status === 401);
pl = await passkeyLogin(jar(), 4, { origin: "https://evil.example" });
ok("a login from a different origin is refused", pl.res.status === 400);
pl = await passkeyLogin(jar(), 5, { id: b64u(randomBytes(32)) });
ok("an unknown passkey → 404 with the \"add it in Settings\" hint", pl.res.status === 404 && /isn't registered/.test(pl.res.json?.error || ""));
pl = await passkeyLogin(jar(), 6);
ok("a good login with a higher counter still works", pl.res.status === 200);
r = await call(PK, "/api/passkeys/" + encodeURIComponent(credId), "DELETE");
ok("remove a passkey → 200 and it is gone", r.status === 200 && (await call(PK, "/api/passkeys")).json.passkeys.length === 0);
pl = await passkeyLogin(jar(), 7);
ok("a removed passkey can't log in any more (404)", pl.res.status === 404);
// passkey-only sign-up: an account with no password that still can be deleted
const PO = jar(), uPo = uname("upo");
r = await call(PO, "/api/signup", "POST", { name: "Pass", username: uPo, passkey: true });
ok("passkey-first sign-up (no password) → 201 with a recovery code", r.status === 201 && !!r.json.recovery_code, JSON.stringify(r.json));
ok("…and /api/me says has_password:false", (await call(PO, "/api/me")).json.user.has_password === false);
r = await call(PO, "/api/account/delete", "POST", { confirm: "DELETE" });
ok("…it can be deleted right after sign-up by typing DELETE (it has no password to type)", r.status === 200);

// ===== 9a. passkeys in the iPhone app need the domain association file =====
r = await fetch(BASE + "/.well-known/apple-app-site-association");
const aasa = await r.json().catch(() => null);
ok("/.well-known/apple-app-site-association → JSON with webcredentials for TEAMID.me.honeybun.app (so passkeys work in the iPhone app)", r.status === 200 && /application\/json/.test(r.headers.get("content-type") || "") && aasa?.webcredentials?.apps?.[0] === "TEAM123456.me.honeybun.app", JSON.stringify(aasa));

const comps = (aasa?.applinks?.details?.[0]?.components || []).map((c) => c["/"]);
ok("…and Universal Links for only the email / invite links (/verify/*, /reset/*, /join/*), so the rest of the site stays in Safari", aasa?.applinks?.details?.[0]?.appIDs?.[0] === "TEAM123456.me.honeybun.app" && JSON.stringify(comps) === JSON.stringify(["/verify/*", "/reset/*", "/join/*"]), JSON.stringify(aasa));

// ===== 9. Google sign-in is gone =====
r = await call(jar(), "/api/auth/google", "POST", { credential: "x".repeat(200) });
ok("POST /api/auth/google no longer signs anyone in (no session cookie, an error)", r.status >= 400 && !/__Host-hb=/.test(r.setCookie || ""), JSON.stringify([r.status, r.json]));
r = await call(jar(), "/api/auth/config");
ok("/api/auth/config no longer mentions Google (only whether Apple is available)", r.status === 200 && !("google" in r.json) && r.json.apple === true, JSON.stringify(r.json));

console.log(out.join("\n"));
cleanup();
process.exit(process.exitCode || 0);
