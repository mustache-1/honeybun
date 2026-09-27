(() => {
  "use strict";

  // ---------- constants ----------
  const CATS = [
    { id: "home", e: "🏠", n: "Housing", c: "#9BB8FF" },
    { id: "groc", e: "🛒", n: "Groceries", c: "#46BE8A" },
    { id: "food", e: "🍜", n: "Eating out", c: "#FF9F5A" },
    { id: "date", e: "💕", n: "Date night", c: "#FF6F9F" },
    { id: "bills", e: "💡", n: "Bills", c: "#FFC94D" },
    { id: "subs", e: "📺", n: "Subscriptions", c: "#8FA3FF" },
    { id: "car", e: "🚗", n: "Getting around", c: "#5CC6D0" },
    { id: "fun", e: "🎁", n: "Gifts & fun", c: "#B79CFF" },
    { id: "pets", e: "🐾", n: "Kids & pets", c: "#D9A27A" },
    { id: "debt", e: "💳", n: "Debt payments", c: "#E88AA8" },
    { id: "other", e: "✨", n: "Other", c: "#B7A9C4" },
  ];
  const catOf = (id) => CATS.find((c) => c.id === id) || CATS[CATS.length - 1];
  const NEEDS = ["home", "groc", "bills", "car", "pets", "debt"];
  const WANTS = ["food", "date", "fun", "subs", "other"];
  const EMOJIS = ["🐰", "🐻", "🐱", "🐶", "🦊", "🐼", "🐨", "🐸", "🐧", "🦄", "🐥", "🐹"];
  const COLORS = ["#FFD6E5", "#FFF0C2", "#DDF5E9", "#E4EDFF", "#EADFFF", "#FFE1CC"];
  const GOAL_EMOJIS = ["🍯", "✈️", "🏠", "💍", "🚗", "🎓", "🐶", "🎄", "🛟", "🎁"];
  const THEMES = [
    { id: "blueberry", n: "Blueberry", c: "#6F93DB" },
    { id: "blush", n: "Blush", c: "#EE7FA3" },
    { id: "lavender", n: "Lavender", c: "#9C82DC" },
    { id: "honey", n: "Honey", c: "#DDA13F" },
  ];
  const FREQ_NAME = { weekly: "Every week", biweekly: "Every 2 weeks", monthly: "Every month" };
  const QUICK_BILLS = [
    { e: "🏠", n: "Rent", c: "home", s: true }, { e: "💡", n: "Electric", c: "bills", s: true }, { e: "💧", n: "Water", c: "bills", s: true },
    { e: "🌐", n: "Internet", c: "bills", s: true }, { e: "📱", n: "Phone", c: "bills", s: false }, { e: "🚗", n: "Car payment", c: "car", s: false },
    { e: "🛡️", n: "Insurance", c: "bills", s: false }, { e: "📺", n: "Netflix", c: "subs", s: true }, { e: "🎵", n: "Spotify", c: "subs", s: false },
    { e: "🏋️", n: "Gym", c: "subs", s: false }, { e: "✨", n: "Something else", c: "other", s: false },
  ];
  // bunny levels
  const TITLES = ["Tiny Sprout", "Curious Kit", "Hoppy Saver", "Carrot Collector", "Burrow Builder", "Budget Bunny", "Clover Keeper", "Garden Guardian", "Moon Hopper", "Honeybun Legend"];
  const UNLOCKS = { 2: "a little sprout", 3: "a pink bow", 5: "a cozy scarf", 7: "a flower crown", 10: "a tiny golden crown" };
  const levelFor = (xp) => { let l = 1; while (xp >= 25 * (l + 1) * l) l++; return l; };
  const levelInfo = (xp) => {
    const l = levelFor(xp), lo = 25 * l * (l - 1), hi = 25 * (l + 1) * l;
    return { l, title: TITLES[Math.min(l, TITLES.length) - 1], lo, hi, pct: Math.max(0, Math.min(1, (xp - lo) / (hi - lo))) };
  };

  // ---------- language (English / Español / 中文) ----------
  const LANGS = { en: "English", es: "Español", zh: "中文" };
  const LANG = (() => {
    let saved = null; try { saved = localStorage.getItem("hb-lang"); } catch {}
    if (LANGS[saved]) return saved;
    const n = (navigator.language || "en").toLowerCase();
    return n.startsWith("zh") ? "zh" : n.startsWith("es") ? "es" : "en";
  })();
  const LOCALE = { en: "en-US", es: "es-US", zh: "zh-CN" }[LANG];
  const DICT = LANG !== "en" && window.HB_I18N ? window.HB_I18N[LANG] : null;
  function tr(str) {
    if (!DICT || typeof str !== "string") return str;
    const k = str.trim(); if (!k) return str;
    if (DICT.exact[k] !== undefined) return str.replace(k, DICT.exact[k]);
    for (const [re, rep] of DICT.patterns) if (re.test(k)) return str.replace(k, k.replace(re, rep));
    let out = k; for (const [re, rep] of DICT.subs) out = out.replace(re, rep);
    return out === k ? str : str.replace(k, out);
  }
  window.HB_TR = tr;
  const TR_ATTRS = ["placeholder", "aria-label", "title"];
  function trNode(node) {
    if (!DICT) return;
    if (node.nodeType === 3) {
      const p = node.parentNode;
      if (!p || p.nodeName === "SCRIPT" || p.nodeName === "STYLE" || p.closest?.("[data-nt]")) return;
      const v = node.nodeValue, t = tr(v); if (t !== v) node.nodeValue = t;
      return;
    }
    if (node.nodeType !== 1 || node.nodeName === "SCRIPT" || node.nodeName === "STYLE" || node.hasAttribute("data-nt")) return;
    for (const a of TR_ATTRS) if (node.hasAttribute(a)) { const v = node.getAttribute(a), t = tr(v); if (t !== v) node.setAttribute(a, t); }
    for (const c of node.childNodes) trNode(c);
  }
  if (DICT) {
    document.documentElement.lang = LANG === "zh" ? "zh-CN" : LANG;
    document.title = tr(document.title);
    trNode(document.body);
    new MutationObserver((muts) => {
      for (const m of muts) {
        if (m.type === "characterData") trNode(m.target);
        else if (m.type === "attributes") trNode(m.target);
        else m.addedNodes.forEach(trNode);
      }
    }).observe(document.body, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: TR_ATTRS });
  }
  function drawLangPickers() {
    document.querySelectorAll("[data-lang-picker]").forEach((box) => {
      box.innerHTML = "";
      Object.entries(LANGS).forEach(([id, name]) => {
        const b = document.createElement("button"); b.type = "button"; b.textContent = name; b.setAttribute("data-nt", "");
        b.setAttribute("aria-pressed", id === LANG ? "true" : "false");
        b.onclick = async () => {
          if (id === LANG) return;
          try { localStorage.setItem("hb-lang", id); } catch {}
          if (ME) { try { await api("/api/me", { method: "PATCH", body: { lang: id } }); } catch {} }
          location.reload();
        };
        box.appendChild(b);
      });
    });
  }

  // ---------- helpers ----------
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const fmt = (n) => (n < 0 ? "−" : "") + "$" + Math.abs(n).toLocaleString(LOCALE, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const pad = (n) => String(n).padStart(2, "0");
  const toS = (d) => d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  const parseD = (s) => { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); };
  const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  const today = () => toS(new Date());
  const ym = (d) => d.slice(0, 7);
  const dayName = (d) => d.toLocaleDateString(LOCALE, { weekday: "short", month: "short", day: "numeric" });
  const shortDay = (d) => d.toLocaleDateString(LOCALE, { month: "short", day: "numeric" });
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  };
  function monthName(m, short) {
    const [y, mo] = m.split("-").map(Number);
    return new Date(y, mo - 1, 1).toLocaleDateString(LOCALE, short ? { month: "short", year: "numeric" } : { month: "long", year: "numeric" });
  }
  function toast(t, actionLabel, action) {
    const el = $("toast"); $("toastText").textContent = t;
    const b = $("toastBtn"); b.hidden = !action; el.classList.toggle("act", !!action);
    if (action) { b.textContent = actionLabel; b.onclick = () => { el.classList.remove("show", "act"); action(); }; }
    el.classList.add("show");
    clearTimeout(toast.t); toast.t = setTimeout(() => el.classList.remove("show", "act"), action ? 6000 : 1900);
  }
  function ask(title, body, yes = "Yes") {
    return new Promise((res) => {
      $("askT").textContent = title; $("askP").textContent = body; $("askYes").textContent = yes;
      const d = $("askDlg"); d.showModal();
      $("askYes").onclick = () => { d.close(); res(true); };
      $("askNo").onclick = () => { d.close(); res(false); };
    });
  }
  function busy(btn, on) { btn.disabled = on; btn.style.opacity = on ? ".6" : ""; }

  async function api(path, { method = "GET", body } = {}) {
    const opts = { method, credentials: "same-origin", headers: {} };
    opts.headers["x-local-date"] = today();
    if (method !== "GET") { opts.headers["content-type"] = "application/json"; opts.body = JSON.stringify(body ?? {}); }
    let res;
    try { res = await fetch(path, opts); }
    catch {
      setOffline(true);
      const cacheKey = "hb-cache:" + path.replace(/month=\d{4}-\d{2}/, (m) => m);
      if (method === "GET" && (path.startsWith("/api/nest?") || path === "/api/me")) {
        const c = store.get(cacheKey); if (c) return JSON.parse(c);
      }
      if (method === "POST" && path === "/api/entries") {
        const q = JSON.parse(store.get("hb-queue") || "[]");
        q.push({ ...body, pending_id: "p" + Date.now() + Math.random().toString(36).slice(2, 6) });
        store.set("hb-queue", JSON.stringify(q));
        return { ok: true, queued: true };
      }
      const e = new Error("You're offline. This needs a connection."); e.offline = true; throw e;
    }
    setOffline(false);
    let data = {};
    try { data = await res.json(); } catch {}
    if (res.ok && method === "GET" && (path.startsWith("/api/nest?") || path === "/api/me")) store.set("hb-cache:" + path, JSON.stringify(data));
    if (!res.ok) {
      const e = new Error(data.error || "Something went wrong. Try again.");
      e.status = res.status;
      if (res.status === 401 && !["/api/login", "/api/me"].includes(path)) { ME = null; showAuth(); }
      throw e;
    }
    return data;
  }


  // ---------- offline ----------
  let OFFLINE = false;
  function setOffline(v) { OFFLINE = v; const b = document.getElementById("offlineBar"); if (b) b.hidden = !v; }
  const queued = () => { try { return JSON.parse(localStorage.getItem("hb-queue") || "[]"); } catch { return []; } };
  let flushing = false;
  async function flushQueue() {
    const q = queued(); if (!q.length || flushing) return;
    flushing = true;
    let sent = 0, i = 0;
    for (; i < q.length; i++) {
      const { pending_id, ...body } = q[i];
      try {
        const res = await fetch("/api/entries", { method: "POST", credentials: "same-origin", headers: { "content-type": "application/json", "x-local-date": today() }, body: JSON.stringify(body) });
        if (res.status >= 500 || res.status === 401) break; // try again later
        sent++;
      } catch { break; }
    }
    store.set("hb-queue", JSON.stringify(q.slice(i)));
    flushing = false;
    if (sent) { toast(`Synced ${sent} offline ${sent === 1 ? "entry" : "entries"}`); try { await loadNest(); } catch {} }
  }
  window.addEventListener("online", () => { setOffline(false); flushQueue(); });
  window.addEventListener("offline", () => setOffline(true));
  if ("serviceWorker" in navigator) window.addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}));

  // ---------- state ----------
  let ME = null, NEST = null, MEMBERS = [], ENTRIES = [], BAL = {}, SETTLES = [], RECUR = [], LOGGED = new Set(), JAR = [];
  let GOALS = [], BUDGETS = {}, DEBTS = [], DEBTPAYS = [], SETUP_DONE = true;
  let MONTH = today().slice(0, 7), YEAR = new Date().getFullYear(), YDATA = null;
  let screen = "loading", filter = null, authMode = "signup", newKind = "couple", calSel = null;
  let mode = "expense", cat = "groc", who = null, shared = true, splitMode = "equal", editing = null;
  let pendingCode = null, resetToken = null, verifyToken = null;
  {
    const j = location.pathname.match(/^\/join\/([A-Za-z0-9-]{4,20})\/?$/);
    if (j) pendingCode = j[1];
    const r = location.pathname.match(/^\/reset\/([A-Za-z0-9_-]{20,100})\/?$/);
    if (r) resetToken = r[1];
    const v = location.pathname.match(/^\/verify\/([A-Za-z0-9_-]{20,100})\/?$/);
    if (v) verifyToken = v[1];
  }
  const member = (id) => MEMBERS.find((m) => m.id === id) || { name: "Someone", emoji: "❔", color: "#EEE" };
  const meMember = () => MEMBERS.find((m) => m.id === ME?.id);
  const others = (id) => MEMBERS.filter((m) => m.id !== id);
  const KIND = () => NEST?.kind || "couple";
  const yesterday = () => toS(addDays(parseD(today()), -1));
  const streakOf = (m) => (m && (m.last_day === today() || m.last_day === yesterday()) ? m.streak : 0);
  const loggedToday = () => meMember()?.last_day === today();

  // ---------- screens ----------
  const APP_SCREENS = ["home", "plan", "add", "stats", "us"];
  const ALL_SCREENS = ["loading", "auth", "reset", "verify", "setup", "onboard", ...APP_SCREENS];
  function show(s) {
    screen = s;
    ALL_SCREENS.forEach((k) => ($("scr-" + k).hidden = k !== s));
    const inApp = APP_SCREENS.includes(s);
    $("nav").hidden = !inApp; $("topBar").hidden = !inApp;
    $("monthNav").style.visibility = s === "stats" || s === "add" ? "hidden" : "";
    document.querySelectorAll("nav.bottom [data-go]").forEach((b) => b.dataset.go === s ? b.setAttribute("aria-current", "page") : b.removeAttribute("aria-current"));
    window.scrollTo(0, 0);
    if (s === "stats") loadYear();
    if (inApp) render();
  }
  document.querySelectorAll("nav.bottom [data-go]").forEach((b) => (b.onclick = () => {
    if (b.dataset.go === "add") openAdd(); else { if (screen === "add") editing = null; show(b.dataset.go); }
  }));

  // ---------- auth ----------
  function showAuth() {
    $("inviteNotice").hidden = !pendingCode;
    $("authCard").hidden = false; $("forgotCard").hidden = true;
    setAuthMode(authMode);
    show("auth");
  }
  function setAuthMode(m) {
    authMode = m;
    document.querySelectorAll("[data-auth]").forEach((b) => b.setAttribute("aria-selected", b.dataset.auth === m ? "true" : "false"));
    $("nameField").hidden = m !== "signup";
    $("forgotWrap").hidden = m !== "login";
    $("aPass").setAttribute("autocomplete", m === "signup" ? "new-password" : "current-password");
    $("aPass").placeholder = m === "signup" ? "At least 8 characters" : "";
    $("authBtn").textContent = m === "signup" ? "Create account" : "Log in";
    $("authErr").textContent = "";
  }
  document.querySelectorAll("[data-auth]").forEach((b) => (b.onclick = () => setAuthMode(b.dataset.auth)));
  $("authForm").onsubmit = async (ev) => {
    ev.preventDefault();
    const email = $("aEmail").value.trim(), password = $("aPass").value, name = $("aName").value.trim();
    if (authMode === "signup" && !name) { $("authErr").textContent = "Enter your name."; $("aName").focus(); return; }
    if (!email) { $("authErr").textContent = "Enter your email."; $("aEmail").focus(); return; }
    if (authMode === "signup" && password.length < 8) { $("authErr").textContent = "Use a password with at least 8 characters."; $("aPass").focus(); return; }
    busy($("authBtn"), true); $("authErr").textContent = "";
    try {
      await api(authMode === "signup" ? "/api/signup" : "/api/login", { method: "POST", body: { name, email, password, lang: LANG } });
      $("aPass").value = "";
      await afterAuth();
    } catch (e) {
      if (e.status === 409) setAuthMode("login");
      $("authErr").textContent = e.message;
    } finally { busy($("authBtn"), false); }
  };
  $("forgotLink").onclick = () => { $("authCard").hidden = true; $("forgotCard").hidden = false; $("fEmail").value = $("aEmail").value; $("forgotMsg").textContent = ""; $("fEmail").focus(); };
  $("backToLogin").onclick = () => { $("forgotCard").hidden = true; $("authCard").hidden = false; setAuthMode("login"); };
  $("forgotForm").onsubmit = async (ev) => {
    ev.preventDefault();
    const email = $("fEmail").value.trim();
    if (!email) { $("forgotMsg").textContent = "Enter your email."; return; }
    busy($("forgotBtn"), true);
    try {
      await api("/api/password/forgot", { method: "POST", body: { email } });
      $("forgotMsg").style.color = "var(--mint-d)";
      $("forgotMsg").textContent = "If there's an account for that email, a reset link is on its way. It works for 1 hour.";
    } catch (e) { $("forgotMsg").style.color = ""; $("forgotMsg").textContent = e.message; }
    finally { busy($("forgotBtn"), false); }
  };
  $("resetForm").onsubmit = async (ev) => {
    ev.preventDefault();
    const p = $("rPass").value, p2 = $("rPass2").value;
    if (p.length < 8) { $("resetErr").textContent = "Use a password with at least 8 characters."; return; }
    if (p !== p2) { $("resetErr").textContent = "The two passwords don't match."; return; }
    busy($("resetBtn"), true);
    try {
      await api("/api/password/reset", { method: "POST", body: { token: resetToken, password: p } });
      resetToken = null; history.replaceState(null, "", "/");
      toast("Password changed");
      await afterAuth();
    } catch (e) { $("resetErr").textContent = e.message; }
    finally { busy($("resetBtn"), false); }
  };


  async function afterAuth() {
    const me = await api("/api/me");
    ME = me.user;
    store.set("hb-had-account", "1");
    const tz = (() => { try { return Intl.DateTimeFormat().resolvedOptions().timeZone; } catch { return null; } })();
    const patch = {};
    if (tz && ME.tz !== tz) patch.tz = tz;
    if (ME.lang && ME.lang !== LANG) {
      if (store.get("hb-lang")) patch.lang = LANG;
      else if (LANGS[ME.lang]) { store.set("hb-lang", ME.lang); location.reload(); return; }
    }
    if (Object.keys(patch).length) api("/api/me", { method: "PATCH", body: patch }).then(() => Object.assign(ME, patch)).catch(() => {});
    flushQueue();
    if (pendingCode) {
      try { await api("/api/nests/join", { method: "POST", body: { code: pendingCode } }); toast("You joined the budget"); }
      catch (e) { $("setupErr").textContent = e.message; toast(e.message); }
      pendingCode = null; history.replaceState(null, "", "/");
      return afterAuth();
    }
    if (!me.nest_id) { $("setupHi").textContent = "Hi, " + ME.name + "!"; drawKinds(); show("setup"); return; }
    await loadNest();
    if (!SETUP_DONE) { openOnboard(false); return; }
    show("home"); bunnyHop();
  }
  async function logout() {
    try { await api("/api/logout", { method: "POST" }); } catch {}
    ME = null; NEST = null; MEMBERS = []; ENTRIES = []; filter = null; editing = null;
    authMode = "login"; showAuth();
  }
  $("setupLogout").onclick = logout;
  $("logoutBtn").onclick = logout;

  // ---------- start or join ----------
  function drawKinds() {
    document.querySelectorAll("#kinds [data-kind]").forEach((b) => {
      b.setAttribute("aria-pressed", b.dataset.kind === newKind ? "true" : "false");
      b.onclick = () => { newKind = b.dataset.kind; drawKinds(); };
    });
  }
  $("createNest").onclick = async () => {
    busy($("createNest"), true); $("setupErr").textContent = "";
    try { await api("/api/nests", { method: "POST", body: { name: $("newNestName").value, kind: newKind } }); await afterAuth(); }
    catch (e) { $("setupErr").textContent = e.message; } finally { busy($("createNest"), false); }
  };
  $("joinNest").onclick = async () => {
    const code = $("joinCode").value.trim();
    if (!code) { $("setupErr").textContent = "Enter the invite code."; $("joinCode").focus(); return; }
    busy($("joinNest"), true); $("setupErr").textContent = "";
    try { await api("/api/nests/join", { method: "POST", body: { code } }); toast("You joined the budget"); await afterAuth(); }
    catch (e) { $("setupErr").textContent = e.message; } finally { busy($("joinNest"), false); }
  };

  // ---------- data ----------
  async function loadNest() {
    const d = await api("/api/nest?month=" + MONTH);
    ME = d.me; NEST = d.nest; MEMBERS = d.members;
    ENTRIES = d.entries.map((e) => ({ ...e, amount: e.amount_cents / 100, shared: !!e.shared, private: !!e.private }));
    queued().filter((q) => (q.date || "").slice(0, 7) === MONTH).forEach((q) => ENTRIES.unshift({
      id: q.pending_id, pending: true, member_id: q.member_id, type: q.type, amount: +q.amount, amount_cents: Math.round(q.amount * 100),
      label: q.label, category: q.category, shared: !!q.shared, split_mode: q.split_mode, split_value: q.split_value, private: !!q.private, date: q.date }));
    BAL = d.balances; SETTLES = d.settlements; RECUR = d.recurring; JAR = d.jar;
    document.documentElement.setAttribute("data-accent", d.nest.accent || "blueberry");
    GOALS = d.goals; DEBTS = d.debts; DEBTPAYS = d.debt_payments; SETUP_DONE = d.setup_done;
    BUDGETS = Object.fromEntries(d.budgets.map((b) => [b.category, b.limit_cents / 100]));
    LOGGED = new Set(d.logged.map((l) => l.recurring_id + "|" + l.occ_date));
    if (!MEMBERS.some((m) => m.id === who)) who = ME.id;
    if (filter && !MEMBERS.some((m) => m.id === filter)) filter = null;
    if (APP_SCREENS.includes(screen)) render();
  }
  async function refresh() {
    if (!ME || !APP_SCREENS.includes(screen) || document.hidden || screen === "add") return;
    if (document.querySelector("dialog[open]")) return;
    try { await loadNest(); } catch {}
  }
  setInterval(refresh, 20000);
  document.addEventListener("visibilitychange", refresh);

  // ---------- carrots, streaks & level-ups ----------
  function gearSvg(l) {
    let g = "";
    if (l >= 10) g += '<path d="M45 52 l4 -15 l11 9 l11 -9 l4 15z" fill="#F6CF73" stroke="#DDA13F" stroke-width="2" stroke-linejoin="round"/><circle cx="60" cy="44" r="2.5" fill="#EE7FA3" stroke="none"/>';
    else if (l >= 7) g += [[40, 56, "#EE7FA3"], [49, 51, "#F6CF73"], [60, 49, "#fff"], [71, 51, "#F6CF73"], [80, 56, "#EE7FA3"]]
      .map(([x, y, c]) => `<circle cx="${x}" cy="${y}" r="4.5" fill="${c}" stroke="#D9668C" stroke-width="1.2"/>`).join("") + '<circle cx="60" cy="49" r="1.6" fill="#F6CF73" stroke="none"/>';
    else if (l >= 2) g += '<path d="M60 49 V37" stroke="#3E9B6B" stroke-width="3" fill="none"/><path d="M60 40 c-8 -1 -13 -7 -11 -12 c7 0 11 4 11 12z" fill="#58B287" stroke="none"/><path d="M60 42 c7 -3 12 -9 10 -13 c-7 1 -10 6 -10 13z" fill="#7FCB9F" stroke="none"/>';
    if (l >= 3) g += '<path d="M79 53 l-9 -6 v12z M79 53 l9 -6 v12z" fill="#EE7FA3" stroke="none"/><circle cx="79" cy="53" r="3" fill="#D9668C" stroke="none"/>';
    if (l >= 5) g += '<path d="M33 104 q27 16 54 0 l2 8 q-29 17 -58 0z" fill="#F6CF73" stroke="none"/><path d="M77 111 l5 14 l8 -3 l-5 -13z" fill="#EDBE55" stroke="none"/>';
    return g;
  }
  function bunnySvg(l) {
    return `<g fill="var(--card)" stroke="var(--ink)" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
      <path d="M44 52 C34 30 34 8 42 6 C50 4 54 28 54 46"/><path d="M76 52 C86 30 86 8 78 6 C70 4 66 28 66 46"/>
      <ellipse cx="60" cy="82" rx="38" ry="34"/>
      <circle cx="47" cy="78" r="3.5" fill="var(--ink)" stroke="none"/><circle cx="73" cy="78" r="3.5" fill="var(--ink)" stroke="none"/>
      <ellipse cx="38" cy="90" rx="6" ry="3.5" fill="#F6B7CB" stroke="none"/><ellipse cx="82" cy="90" rx="6" ry="3.5" fill="#F6B7CB" stroke="none"/>
      <path d="M52 89 q8 8 16 0" fill="none" stroke-width="3"/>${gearSvg(l)}</g>`;
  }
  function rewardToast(rw, msg) {
    if (!rw) { toast(msg); return; }
    toast(rw.gained > 0 ? `${msg}  +${rw.gained} 🥕` : msg);
    if (rw.leveled) setTimeout(() => showLevelUp(rw.level), 700);
    else if (rw.streak_up) setTimeout(() => toast(`🐾 ${rw.streak}-day hop streak!`), 2000);
    else if (rw.first_today && rw.streak === 1) setTimeout(() => toast("🐾 Streak started. Come back tomorrow!"), 2000);
  }
  function showLevelUp(l) {
    const title = TITLES[Math.min(l, TITLES.length) - 1];
    $("lvBunny").innerHTML = bunnySvg(l);
    $("lvKicker").textContent = "Level up!";
    $("lvTitle").textContent = `Level ${l} · ${title}`;
    const unlock = Object.keys(UNLOCKS).map(Number).filter((n) => n <= l).pop();
    $("lvText").textContent = UNLOCKS[l] ? `Your bunny unlocked ${UNLOCKS[l]}!` : unlock ? "Keep hopping. Your bunny is proud of you." : "Keep logging to grow your bunny.";
    const c = $("confetti"); c.innerHTML = "";
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches)
      for (let i = 0; i < 18; i++) {
        const e = document.createElement("i"); e.textContent = ["🥕", "✨", "💕"][i % 3];
        e.style.left = Math.random() * 100 + "%"; e.style.animationDelay = Math.random() * 0.6 + "s";
        c.appendChild(e);
      }
    $("levelDlg").showModal();
  }
  $("lvOk").onclick = () => $("levelDlg").close();

  function renderPill() {
    const m = meMember(); if (!m) return;
    const li = levelInfo(m.xp || 0), st = streakOf(m), done = loggedToday();
    $("burrowPill").innerHTML = `<span class="today-dot ${done ? "done" : ""}"></span>
      <span class="st ${st ? "" : "cold"}">🐾 ${st}</span>
      <span class="lv">Lv ${li.l} · ${esc(li.title)}<small>${done ? "You hopped today ♡" : st ? "Log one thing today to keep your streak" : "Log one thing today to start a streak"}</small>
      <span class="xpbar" style="display:block"><i style="width:${li.pct * 100}%"></i></span></span>
      <span class="st">🥕 ${m.xp || 0}</span>`;
    $("gear").innerHTML = gearSvg(li.l);
  }
  $("burrowPill").onclick = () => show("stats");

  const BADGES = [
    { e: "🐣", n: "First hop", d: "Log your first thing", ok: (m) => m.logs >= 1 },
    { e: "🐾", n: "3-day hop", d: "Keep a 3-day streak", ok: (m) => m.best_streak >= 3 },
    { e: "🌟", n: "Week hopper", d: "Keep a 7-day streak", ok: (m) => m.best_streak >= 7 },
    { e: "🏅", n: "Month marathon", d: "Keep a 30-day streak", ok: (m) => m.best_streak >= 30 },
    { e: "🥕", n: "Carrot counter", d: "Log 50 things", ok: (m) => m.logs >= 50 },
    { e: "🧺", n: "Carrot basket", d: "Log 200 things", ok: (m) => m.logs >= 200 },
    { e: "💰", n: "Payday planner", d: "Add a payday", ok: () => RECUR.some((r) => r.type === "income") },
    { e: "📅", n: "Bill boss", d: "Add 3 bills", ok: () => RECUR.filter((r) => r.type === "expense").length >= 3 },
    { e: "🎯", n: "Limit setter", d: "Set a monthly budget", ok: () => Object.keys(BUDGETS).length > 0 },
    { e: "🍯", n: "Goal getter", d: "Reach a savings goal", ok: () => GOALS.some((g) => g.saved_cents >= g.target_cents) },
    { e: "🎉", n: "Debt free-ish", d: "Pay off a debt", ok: () => DEBTS.some((d) => d.paid_cents >= d.start_cents) },
    { e: "💞", n: "Better together", d: "Share your budget", ok: () => MEMBERS.length >= 2 },
    { e: "🏡", n: "Burrow builder", d: "Reach level 5", ok: (m) => levelFor(m.xp) >= 5 },
    { e: "🌙", n: "Moon hopper", d: "Reach level 9", ok: (m) => levelFor(m.xp) >= 9 },
    { e: "👑", n: "Legend", d: "Reach level 10", ok: (m) => levelFor(m.xp) >= 10 },
    { e: "🗓️", n: "Year in review", d: "Log something in 6 different months", ok: () => YDATA && new Set(YDATA.entries.map((e) => e.date.slice(0, 7))).size >= 6 },
  ];
  function renderBurrow() {
    const m = meMember(); if (!m) return;
    const li = levelInfo(m.xp || 0), st = streakOf(m);
    // this week's hop days (Mon–Sun) from the current streak
    const t = parseD(today()), mon = addDays(t, -((t.getDay() + 6) % 7));
    const streakDays = new Set();
    if (m.last_day && st) for (let i = 0; i < Math.min(st, 7); i++) streakDays.add(toS(addDays(parseD(m.last_day), -i)));
    const week = [0, 1, 2, 3, 4, 5, 6].map((i) => {
      const d = toS(addDays(mon, i)), n = addDays(mon, i).toLocaleDateString(LOCALE, { weekday: "narrow" });
      return `<div><i class="${streakDays.has(d) ? "on" : ""} ${d === today() ? "today" : ""}">${streakDays.has(d) ? "🐾" : ""}</i>${n}</div>`;
    }).join("");
    $("burrow").innerHTML = `<svg viewBox="0 0 120 128" aria-hidden="true">${bunnySvg(li.l)}</svg>
      <div class="info"><div class="kick">Level ${li.l}</div><h2>${esc(li.title)}</h2>
      <div class="xpbar"><i style="width:${li.pct * 100}%"></i></div>
      <div class="nums"><span>🥕 ${m.xp || 0}</span><span>${li.hi - (m.xp || 0)} to level ${li.l + 1}</span></div>
      <div class="chips"><span>🐾 ${st}-day streak</span><span>Best ${m.best_streak || 0}</span></div>
      <div class="week">${week}</div></div>`;
    const bg = $("badges"); bg.innerHTML = ""; let got = 0;
    BADGES.forEach((b) => {
      const on = !!b.ok(m); if (on) got++;
      const el = document.createElement("button"); el.className = "badge" + (on ? " on" : "");
      el.innerHTML = `<i>${b.e}</i>${esc(b.n)}`;
      el.onclick = () => toast(on ? `${b.n}: unlocked ♡` : `${b.n}: ${b.d}`);
      bg.appendChild(el);
    });
    $("badgeCount").textContent = `${got} of ${BADGES.length}`;
    const wk = (() => { const d = parseD(today()); return toS(addDays(d, -((d.getDay() + 6) % 7))); })();
    $("boardWrap").hidden = MEMBERS.length < 2;
    const rows = MEMBERS.map((x) => ({ x, v: x.week_key === wk ? x.week_xp : 0 })).sort((a, b) => b.v - a.v);
    $("board").innerHTML = rows.map((r, i) => `<div class="board-row"><span class="rk">${i + 1}</span><span class="face" style="background:${esc(r.x.color)}">${esc(r.x.emoji)}</span>
      <span class="nm">${esc(r.x.name)}${r.x.id === ME.id ? " (you)" : ""}</span><span class="xp">🥕 ${r.v}</span></div>`).join("");
  }

  // ---------- first-time setup ----------
  let ob = { steps: [], i: 0, rerun: false, pay: {}, bill: {} };
  function freshPay() { return { amount: "", freq: "biweekly", date: today(), who: ME.id, label: "Paycheck" }; }
  function freshBill() { return { pick: null, label: "", cat: "home", amount: "", freq: "monthly", date: "", shared: MEMBERS.length > 1 }; }
  function openOnboard(rerun) {
    ob.rerun = rerun;
    const invite = KIND() !== "solo" && MEMBERS.length < 2 && !rerun;
    ob.steps = rerun ? ["paydays", "bills", "done"] : ["buddy", ...(invite ? ["invite"] : []), "paydays", "bills", "done"];
    ob.i = 0; ob.pay = freshPay(); ob.bill = freshBill();
    show("onboard"); drawOb();
  }
  const ICON = {
    heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>',
    coin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="8"/><path d="M12 7v10M14.5 9.5c0-1-1.1-1.8-2.5-1.8s-2.5.8-2.5 1.9 1 1.6 2.5 1.9 2.5.9 2.5 2-1.1 1.8-2.5 1.8-2.5-.8-2.5-1.8"/></svg>',
  };
  function recurRow(r) {
    const isIn = r.type === "income", n = nextOcc(r);
    const li = document.createElement("li");
    li.innerHTML = `<span>${isIn ? "💰" : catOf(r.category).e}</span><span class="t">${esc(r.label)} · ${fmt(r.amount_cents / 100)}<small>${FREQ_NAME[r.freq]}${n ? ", next " + shortDay(n) : ""}${isIn ? ", " + esc(member(r.member_id).name) : r.shared ? ", split" : ""}</small></span><button aria-label="Remove">✕</button>`;
    li.querySelector("button").onclick = async () => { try { await api("/api/recurring/" + r.id, { method: "DELETE" }); await loadNest(); drawOb(); } catch (e) { $("obErr").textContent = e.message; } };
    return li;
  }
  function drawOb() {
    const step = ob.steps[ob.i], last = ob.steps.length - 1, body = $("obBody");
    $("obProg").style.width = (ob.i / last) * 100 + "%";
    $("obBack").style.visibility = ob.i === 0 ? "hidden" : "";
    $("obSkip").style.visibility = step === "done" ? "hidden" : "";
    $("obErr").textContent = "";
    $("obNext").textContent = step === "done" ? "Go to my budget" : step === "bills" ? "Finish" : "Next";
    const isSolo = KIND() === "solo";
    if (step === "buddy") {
      body.innerHTML = `<div class="ob-art"><img src="/icon-192.png" alt=""></div><h1>Hi ${esc(ME.name)}!</h1>
        <p class="lead">Let's set up your budget. It takes about a minute. First, pick the little buddy that shows next to everything you add.</p>
        <div class="emojis" id="obEmojis"></div>`;
      const mine = meMember(), g = $("obEmojis");
      EMOJIS.forEach((e) => {
        const b = document.createElement("button"); b.type = "button"; b.textContent = e;
        b.setAttribute("aria-pressed", mine && mine.emoji === e ? "true" : "false");
        b.onclick = async () => { if (mine) mine.emoji = e; drawOb(); try { await api("/api/me", { method: "PATCH", body: { emoji: e } }); } catch (err) { $("obErr").textContent = err.message; } };
        g.appendChild(b);
      });
    }
    if (step === "invite") {
      const who = KIND() === "family" ? "your family" : "your partner";
      body.innerHTML = `<div class="ob-art">${ICON.heart}</div><h1>Invite ${who}</h1>
        <p class="lead">Send them this link. When they join, you'll share one budget and see the same bills.</p>
        <div class="big-code">${esc(prettyCode(NEST.invite_code))}</div>
        <div class="btn-row" style="justify-content:center;margin-top:12px">${navigator.share ? '<button class="small" id="obShare">Share link</button>' : ""}<button class="small" id="obCopy">Copy link</button></div>
        <p class="hint center" style="margin-top:12px">You can always find this later in Together.</p>`;
      $("obCopy").onclick = $("copyInvite").onclick;
      if ($("obShare")) $("obShare").onclick = $("shareInvite").onclick;
    }
    if (step === "paydays") {
      const p = ob.pay, pays = RECUR.filter((r) => r.type === "income");
      body.innerHTML = `<div class="ob-art">${ICON.coin}</div><h1>When do you get paid?</h1>
        <p class="lead">Add each paycheck once. Honeybun uses it to show what's due before payday.</p>
        ${MEMBERS.length > 1 ? '<div class="field" style="margin-top:0"><span class="lbl">Who gets paid?</span><div class="whos" id="obPayWho"></div></div>' : ""}
        <div class="row2"><div class="field"><label for="obPayAmt">Amount</label><input id="obPayAmt" type="number" inputmode="decimal" min="0" step="0.01" placeholder="1,800"></div>
        <div class="field"><label for="obPayFreq">How often</label><select id="obPayFreq"><option value="weekly">Every week</option><option value="biweekly">Every 2 weeks</option><option value="monthly">Every month</option></select></div></div>
        <div class="field"><label for="obPayDate">Next payday</label><input id="obPayDate" type="date"></div>
        <button class="small" id="obPayAdd" style="margin-top:12px">Add payday</button>
        <ul class="added" id="obPays"></ul>`;
      $("obPayAmt").value = p.amount; $("obPayFreq").value = p.freq; $("obPayDate").value = p.date;
      $("obPayAmt").oninput = (e) => (p.amount = e.target.value);
      $("obPayFreq").onchange = (e) => (p.freq = e.target.value);
      $("obPayDate").onchange = (e) => (p.date = e.target.value);
      if ($("obPayWho")) MEMBERS.forEach((m) => {
        const b = document.createElement("button"); b.type = "button"; b.innerHTML = `<i style="background:${esc(m.color)}">${esc(m.emoji)}</i>${esc(m.name)}`;
        b.setAttribute("aria-pressed", m.id === p.who ? "true" : "false"); b.onclick = () => { p.who = m.id; drawOb(); }; $("obPayWho").appendChild(b);
      });
      pays.forEach((r) => $("obPays").appendChild(recurRow(r)));
      $("obPayAdd").onclick = async () => {
        if (!(parseFloat(p.amount) > 0)) { $("obErr").textContent = "Enter how much you get paid."; $("obPayAmt").focus(); return; }
        if (!p.date) { $("obErr").textContent = "Pick your next payday."; return; }
        try {
          await api("/api/recurring", { method: "POST", body: { type: "income", amount: parseFloat(p.amount), label: tr(member(p.who).name + "'s paycheck"), member_id: p.who, freq: p.freq, date: p.date } });
          ob.pay = freshPay(); ob.pay.who = p.who; await loadNest(); drawOb(); toast("Payday added");
        } catch (e) { $("obErr").textContent = e.message; }
      };
    }
    if (step === "bills") {
      const b = ob.bill, bills = RECUR.filter((r) => r.type === "expense");
      body.innerHTML = `<div class="ob-art">${ICON.cal}</div><h1>Rent, bills & subscriptions</h1>
        <p class="lead">Add the things you pay every month. We'll show them before they're due${isSolo ? "" : " and split them for you"}.</p>
        <div class="quick" id="obQuick"></div>
        <div class="field"><label for="obBillName">Name</label><input id="obBillName" maxlength="40" placeholder="Rent"></div>
        <div class="row2"><div class="field"><label for="obBillAmt">Amount</label><input id="obBillAmt" type="number" inputmode="decimal" min="0" step="0.01" placeholder="1,500"></div>
        <div class="field"><label for="obBillDate">Next due date</label><input id="obBillDate" type="date"></div></div>
        <div class="field"><label for="obBillFreq">How often</label><select id="obBillFreq"><option value="monthly">Every month</option><option value="biweekly">Every 2 weeks</option><option value="weekly">Every week</option></select></div>
        ${MEMBERS.length > 1 ? '<div class="field"><span class="lbl">Split</span><div class="split"><button type="button" id="obSplit">Split evenly</button><button type="button" id="obMine">Just mine</button></div></div>' : ""}
        <button class="small" id="obBillAdd" style="margin-top:12px">Add bill</button>
        <ul class="added" id="obBills"></ul>`;
      QUICK_BILLS.forEach((q) => {
        const el = document.createElement("button"); el.type = "button"; el.textContent = `${q.e} ${q.n}`;
        el.setAttribute("aria-pressed", b.pick === q.n ? "true" : "false");
        el.onclick = () => { b.pick = q.n; b.label = q.n === "Something else" ? "" : q.n; b.cat = q.c; b.shared = MEMBERS.length > 1 && q.s; drawOb(); (q.n === "Something else" ? $("obBillName") : $("obBillAmt")).focus(); };
        $("obQuick").appendChild(el);
      });
      $("obBillName").value = b.label; $("obBillAmt").value = b.amount; $("obBillDate").value = b.date; $("obBillFreq").value = b.freq;
      $("obBillName").oninput = (e) => (b.label = e.target.value);
      $("obBillAmt").oninput = (e) => (b.amount = e.target.value);
      $("obBillDate").onchange = (e) => (b.date = e.target.value);
      $("obBillFreq").onchange = (e) => (b.freq = e.target.value);
      if ($("obSplit")) {
        $("obSplit").setAttribute("aria-pressed", b.shared ? "true" : "false"); $("obMine").setAttribute("aria-pressed", b.shared ? "false" : "true");
        $("obSplit").onclick = () => { b.shared = true; drawOb(); }; $("obMine").onclick = () => { b.shared = false; drawOb(); };
      }
      bills.forEach((r) => $("obBills").appendChild(recurRow(r)));
      $("obBillAdd").onclick = async () => {
        if (!b.label.trim()) { $("obErr").textContent = "Name the bill, or tap one above."; $("obBillName").focus(); return; }
        if (!(parseFloat(b.amount) > 0)) { $("obErr").textContent = "Enter the amount."; $("obBillAmt").focus(); return; }
        if (!b.date) { $("obErr").textContent = "Pick the next due date."; $("obBillDate").focus(); return; }
        try {
          await api("/api/recurring", { method: "POST", body: { type: "expense", amount: parseFloat(b.amount), label: tr(b.label.trim()), category: b.cat, member_id: ME.id, shared: b.shared, split_mode: "equal", freq: b.freq, date: b.date } });
          ob.bill = freshBill(); await loadNest(); drawOb(); toast(`${b.label.trim()} added`);
        } catch (e) { $("obErr").textContent = e.message; }
      };
    }
    if (step === "done") {
      const np = RECUR.filter((r) => r.type === "income").length, nb = RECUR.filter((r) => r.type === "expense").length;
      body.innerHTML = `<div class="ob-art"><img src="/icon-192.png" alt=""></div><h1>You're all set</h1>
        <p class="lead">${np} payday${np === 1 ? "" : "s"} and ${nb} bill${nb === 1 ? "" : "s"} added. You can change them anytime in Plan.</p>
        <div class="card" style="text-align:left"><h2 style="font-size:1rem">How your bunny grows 🥕</h2>
        <p class="sub" style="margin-top:6px">Earn carrots every time you log spending, pay a bill, or save. Log something each day to build your hop streak 🐾, level up, and unlock outfits for your bunny.</p></div>`;
    }
  }
  $("obBack").onclick = () => { if (ob.i > 0) { ob.i--; drawOb(); window.scrollTo(0, 0); } };
  $("obSkip").onclick = () => { ob.i = Math.min(ob.i + 1, ob.steps.length - 1); drawOb(); window.scrollTo(0, 0); };
  $("obNext").onclick = async () => {
    if (ob.steps[ob.i] !== "done") { ob.i++; drawOb(); window.scrollTo(0, 0); return; }
    let rw = null;
    try { rw = (await api("/api/setup/done", { method: "POST" })).reward; } catch {}
    await loadNest(); show("home"); bunnyHop();
    if (rw) rewardToast(rw, "Setup complete");
  };
  $("rerunSetup").onclick = () => openOnboard(true);

  // ---------- bills & paydays: upcoming ----------
  function occurrences(r, from, to) {
    const out = [], a = parseD(r.anchor_date);
    if (r.freq === "monthly") {
      const day = a.getDate();
      let y = from.getFullYear(), m = from.getMonth();
      for (let i = 0; i < 26; i++) {
        const d = new Date(y, m, Math.min(day, new Date(y, m + 1, 0).getDate()));
        if (d > to) break;
        if (d >= from && d >= a) out.push(d);
        if (++m > 11) { m = 0; y++; }
      }
    } else {
      const step = r.freq === "weekly" ? 7 : 14;
      let d = a;
      if (d < from) d = addDays(a, Math.ceil(Math.round((from - a) / 86400000) / step) * step);
      for (let i = 0; d <= to && i < 60; i++) { out.push(d); d = addDays(d, step); }
    }
    return out;
  }
  const isLogged = (r, d) => LOGGED.has(r.id + "|" + toS(d));
  function nextOcc(r) { const t = parseD(today()); return occurrences(r, t, addDays(t, 400))[0]; }
  function upcoming() {
    const t = parseD(today());
    let payday = null, pays = [];
    for (const r of RECUR.filter((r) => r.type === "income")) {
      const d = occurrences(r, t, addDays(t, 62)).find((d) => !isLogged(r, d));
      if (!d) continue;
      if (!payday || d < payday) { payday = d; pays = [{ r, d }]; }
      else if (+d === +payday) pays.push({ r, d });
    }
    const until = payday ? addDays(payday, -1) : addDays(t, 30);
    const bills = [];
    for (const r of RECUR.filter((r) => r.type === "expense"))
      for (const d of occurrences(r, addDays(t, -31), until)) if (!isLogged(r, d)) bills.push({ r, d, late: d < t });
    bills.sort((a, b) => a.d - b.d);
    return { payday, pays, bills };
  }
  async function logOcc(r, d, btn) {
    if (btn) busy(btn, true);
    try {
      const res = await api(`/api/recurring/${r.id}/log`, { method: "POST", body: { occ_date: toS(d) } });
      await loadNest();
      rewardToast(res.reward, r.type === "income" ? "Payday logged" : r.label + " marked paid");
      bunnyHop();
    } catch (e) { toast(e.message); if (btn) busy(btn, false); }
  }


  // ---------- rendering ----------
  function setBunny(left, inc, out, any) {
    const r = inc > 0 ? out / inc : out > 0 ? 2 : 0;
    let msg, path = "M53 90 q3.5 4 7 0 q3.5 4 7 0", p = "";
    if (!any) msg = loggedToday() ? "Add your first paycheck to begin." : "Log something today to start your hop streak 🐾";
    else if (inc === 0) { msg = "No income logged yet."; path = "M54 91 h12"; }
    else if (r > 1) { msg = "A little over this month."; path = "M53 93 q7 -5 14 0"; }
    else if (r > 0.8) { msg = "Almost at the limit."; path = "M54 91 q6 1.5 12 0"; }
    else {
      msg = Math.round((1 - r) * 100) + `% of this month is still ${KIND() === "solo" ? "yours" : "ours"}.`;
      if (r < 0.5) { path = "M52 89 q8 8 16 0"; p = '<path d="M100 40 c-3-5-10-2-6 4 l6 5 6-5 c4-6-3-9-6-4z" fill="#EE7FA3" stroke="none"/>'; }
    }
    $("mouth").setAttribute("d", path); $("prop").innerHTML = p; $("bubble").textContent = msg;
  }
  function bunnyHop() { const b = $("bunny"); b.classList.remove("hop"); void b.getBoundingClientRect(); b.classList.add("hop"); }

  function splitText(e) {
    if (!e.shared) return e.private ? "personal, private" : "personal";
    if (e.split_mode === "percent" && MEMBERS.length === 2) return `split ${e.split_value}/${100 - e.split_value}`;
    if (e.split_mode === "percent") return `split, ${member(e.member_id).name} covers ${e.split_value}%`;
    if (e.split_mode === "owed") {
      const o = others(e.member_id);
      return o.length === 1 ? `${o[0].name} owes ${fmt(e.split_value / 100)}` : `others owe ${fmt(e.split_value / 100)}`;
    }
    return "split evenly";
  }

  function entryPayload(e) {
    return { type: e.type, amount: e.amount, label: e.label, category: e.category, member_id: e.member_id, shared: e.shared,
      split_mode: e.split_mode, split_value: e.split_mode === "owed" ? e.split_value / 100 : e.split_value,
      private: e.private, date: e.date, recurring_id: e.recurring_id, occ_date: e.occ_date, restore: true };
  }
  async function deleteEntry(e) {
    if (e.pending) { store.set("hb-queue", JSON.stringify(queued().filter((q) => q.pending_id !== e.id))); await loadNest(); toast("Removed"); return; }
    try {
      await api("/api/entries/" + e.id, { method: "DELETE" });
      await loadNest();
      toast("Deleted " + e.label, "Undo", async () => {
        try { await api("/api/entries", { method: "POST", body: entryPayload(e) }); await loadNest(); toast("Restored"); }
        catch (err) { toast(err.message); }
      });
    } catch (err) { toast(err.message); }
  }

  function entryLi(e) {
    const m = member(e.member_id), c = CATS.find((x) => x.id === e.category) || CATS[8], isIn = e.type === "income";
    const li = document.createElement("li"); li.className = "clickable";
    li.innerHTML = `<div class="ic" style="${isIn ? "background:var(--mint-t)" : ""}">${isIn ? "💰" : c.e}</div>
      <div class="mid"><div class="t">${esc(e.label)}${e.private ? ' <span class="lock" title="Only you can see this">🔒</span>' : ""}</div>
      <div class="s">${esc(m.emoji)} ${esc(m.name)}, ${shortDay(parseD(e.date))}${isIn ? "" : ", " + esc(splitText(e))}</div></div>
      <div class="amt ${isIn ? "in" : ""}">${isIn ? "+" : "−"}${fmt(e.amount)}</div>
      <button class="del" aria-label="Delete ${esc(e.label)}">✕</button>`;
    li.onclick = () => openEditEntry(e);
    li.querySelector(".del").onclick = (ev) => { ev.stopPropagation(); deleteEntry(e); };
    return li;
  }

  function inviteUrl() { return location.origin + "/join/" + NEST.invite_code; }
  const prettyCode = (c) => c.slice(0, 4) + "-" + c.slice(4);

  function pairs() {
    const debt = [], cred = [];
    MEMBERS.forEach((m) => { const v = (BAL[m.id] || 0) / 100; if (v < -0.005) debt.push({ m, v: -v }); else if (v > 0.005) cred.push({ m, v }); });
    const out = []; let i = 0, j = 0;
    while (i < debt.length && j < cred.length) {
      const pay = Math.min(debt[i].v, cred[j].v);
      out.push({ from: debt[i].m, to: cred[j].m, amount: Math.round(pay * 100) / 100 });
      debt[i].v -= pay; cred[j].v -= pay;
      if (debt[i].v < 0.005) i++; if (cred[j].v < 0.005) j++;
    }
    return out;
  }

  function renderDue(left) {
    const box = $("dueCard");
    if (!RECUR.length) {
      box.innerHTML = `<div class="due-h"><h2>Bills &amp; paydays</h2></div>
        <p class="due-empty">Add rent, bills, and paydays once. Honeybun will show what's due before your next paycheck.</p>
        <button class="small" id="dueAdd" style="margin-top:8px">Add a bill or payday</button>`;
      $("dueAdd").onclick = () => openAdd({ repeat: "monthly" });
      return;
    }
    const { payday, pays, bills } = upcoming();
    const total = bills.reduce((s, b) => s + b.r.amount_cents / 100, 0);
    box.innerHTML = `<div class="due-h"><h2>${payday ? "Before payday" : "Coming up"}</h2><span>${payday ? dayName(payday) : "next 30 days"}</span></div>`;
    if (!bills.length) box.insertAdjacentHTML("beforeend", `<p class="due-empty">Nothing due${payday ? " before payday" : " soon"} ♡</p>`);
    bills.forEach((b) => {
      const c = CATS.find((x) => x.id === b.r.category) || CATS[4];
      const row = document.createElement("div"); row.className = "due-row";
      row.innerHTML = `<div class="ic">${c.e}</div><div class="mid"><div class="t">${esc(b.r.label)}</div>
        <div class="s ${b.late ? "late" : ""}">${b.late ? "Overdue, was due " : "Due "}${shortDay(b.d)}</div></div>
        <div class="amt">${fmt(b.r.amount_cents / 100)}</div><button class="mini">Paid</button>`;
      row.querySelector("button").onclick = (ev) => logOcc(b.r, b.d, ev.currentTarget);
      box.appendChild(row);
    });
    pays.forEach((p) => {
      const m = member(p.r.member_id);
      const row = document.createElement("div"); row.className = "due-row";
      row.innerHTML = `<div class="ic" style="background:var(--mint-t)">💰</div><div class="mid"><div class="t">${esc(p.r.label)}</div>
        <div class="s">${esc(m.name)} gets paid ${shortDay(p.d)}</div></div>
        <div class="amt" style="color:var(--mint-d)">+${fmt(p.r.amount_cents / 100)}</div><button class="mini inc">Got it</button>`;
      row.querySelector("button").onclick = (ev) => logOcc(p.r, p.d, ev.currentTarget);
      box.appendChild(row);
    });
    if (bills.length) box.insertAdjacentHTML("beforeend",
      `<div class="due-foot"><span>Due ${fmt(total)}</span><span class="${left - total < 0 ? "neg" : ""}">Left after bills ${fmt(left - total)}</span></div>`);
  }


  const spentByCat = () => {
    const by = {};
    ENTRIES.filter((e) => e.type === "expense").forEach((e) => (by[e.category] = (by[e.category] || 0) + e.amount));
    return by;
  };

  function render() {
    if (!NEST) return;
    document.documentElement.setAttribute("data-accent", NEST.accent || "blueberry");
    $("monthLbl").textContent = monthName(MONTH, true);
    const names = MEMBERS.map((m) => m.name);
    $("hi").textContent = NEST.name || (MEMBERS.length === 2 ? `${names[0]} & ${names[1]}` : MEMBERS.length === 1 ? names[0] : "Our family");
    $("usLabel").textContent = KIND() === "solo" && MEMBERS.length < 2 ? "Me" : "Together";

    const all = ENTRIES, view = filter ? all.filter((e) => e.member_id === filter) : all;
    const sum = (arr, t) => arr.filter((e) => e.type === t).reduce((s, e) => s + e.amount, 0);
    const inc = sum(view, "income"), out = sum(view, "expense"), left = inc - out;

    if (screen === "home") {
      const lbl = { solo: "Left for me this month", couple: "Left for us this month", family: "Left for our family this month" }[KIND()];
      $("leftLbl").textContent = filter ? member(filter).name + "'s balance" : lbl;
      $("leftAmt").textContent = fmt(left); $("leftAmt").classList.toggle("neg", left < 0);
      $("meter").style.width = inc > 0 ? Math.min(100, (out / inc) * 100) + "%" : out > 0 ? "100%" : "0";
      $("flowIn").textContent = "+" + fmt(inc) + " in"; $("flowOut").textContent = fmt(out) + " out";
      setBunny(left, inc, out, view.length > 0);
      renderPill();
      $("verifyBanner").hidden = !!ME.verified;
      const isThisMonth = MONTH === today().slice(0, 7);
      $("dueCard").hidden = !isThisMonth;
      if (isThisMonth) renderDue(sum(all, "income") - sum(all, "expense"));

      // budget heads-up
      const by = spentByCat();
      const warn = Object.entries(BUDGETS).map(([c, lim]) => ({ c, lim, sp: by[c] || 0 })).filter((x) => x.sp >= x.lim * 0.8).sort((a, b) => b.sp / b.lim - a.sp / a.lim).slice(0, 2);
      $("homeBud").innerHTML = warn.map((x) => `<div class="home-bud"><span>${catOf(x.c).e} ${esc(catOf(x.c).n)}</span>
        <small>${x.sp > x.lim ? "Over by " + fmt(x.sp - x.lim) : fmt(x.lim - x.sp) + " left"}</small></div>`).join("");
      $("homeBud").onclick = () => show("plan");

      const cp = $("couple"); cp.innerHTML = "";
      const amp = () => { const h = document.createElement("span"); h.className = "heart"; h.textContent = "&"; h.setAttribute("aria-hidden", "true"); return h; };
      MEMBERS.forEach((m, i) => {
        if (i > 0 && MEMBERS.length === 2) cp.appendChild(amp());
        const mi = all.filter((e) => e.member_id === m.id && e.type === "income").reduce((s, e) => s + e.amount, 0);
        const mo = all.filter((e) => e.member_id === m.id && e.type === "expense").reduce((s, e) => s + e.amount, 0);
        const b = document.createElement("button"); b.className = "pal"; b.setAttribute("aria-pressed", filter === m.id ? "true" : "false");
        b.setAttribute("aria-label", `${m.name}: earned ${fmt(mi)}, paid ${fmt(mo)}. Tap to see only theirs.`);
        b.innerHTML = `<span class="face" style="background:${esc(m.color)}">${esc(m.emoji)}</span><span class="nm">${esc(m.name)}</span><span class="st">Lv ${levelFor(m.xp || 0)} · 🐾 ${streakOf(m)}<br>+${fmt(mi)} / −${fmt(mo).replace("−", "")}</span>`;
        b.onclick = () => { filter = filter === m.id ? null : m.id; render(); };
        cp.appendChild(b);
      });
      if (MEMBERS.length === 1 && KIND() !== "solo") {
        const b = document.createElement("button"); b.className = "pal";
        b.innerHTML = `<span class="face" style="background:var(--card);box-shadow:inset 0 0 0 2px var(--line);color:var(--soft)">＋</span><span class="nm">Invite</span><span class="st">${KIND() === "family" ? "your family" : "your partner"}</span>`;
        b.onclick = () => { show("us"); setTimeout(() => $("inviteH").scrollIntoView({ behavior: "smooth" }), 40); };
        cp.append(amp(), b);
      }
      const fn = $("filterNote");
      if (filter) {
        fn.hidden = false; fn.textContent = `Only ${member(filter).name}'s money. `;
        const c = document.createElement("button"); c.className = "linkbtn"; c.textContent = "Show everyone"; c.onclick = () => { filter = null; render(); }; fn.appendChild(c);
      } else fn.hidden = true;

      const rc = $("recent"); rc.innerHTML = "";
      if (!view.length) rc.innerHTML = `<li class="empty" style="justify-content:center;border:0">Nothing yet for ${esc(monthName(MONTH))}. Tap + to add something.</li>`;
      view.slice(0, 5).forEach((e) => rc.appendChild(entryLi(e)));
      $("seeAll").hidden = view.length <= 5;
    }

    if (screen === "add") renderForm();
    if (screen === "plan") renderPlan();
    if (screen === "stats") renderStats();

    if (screen === "us") {
      $("settleWrap").hidden = MEMBERS.length < 2;
      const st = $("settle"), ps = pairs();
      if (!ps.length) st.innerHTML = `<div class="owe">You're all even ♡</div>`;
      else {
        st.innerHTML = `<p style="margin:0;color:var(--soft);font-weight:700;font-size:.85rem">From all split expenses so far</p>`;
        ps.forEach((p) => {
          const d = document.createElement("div"); d.className = "owe";
          d.innerHTML = `<span class="f">${esc(p.from.emoji)}</span><span>${esc(p.from.name)} owes ${esc(p.to.name)}</span><span class="amt">${fmt(p.amount)}</span><button class="mini inc">Mark paid</button>`;
          d.querySelector("button").onclick = () => openSettle(p);
          st.appendChild(d);
        });
      }
      const sh = $("settleHist"); sh.innerHTML = "";
      SETTLES.slice(0, 5).forEach((s) => {
        const li = document.createElement("li");
        li.innerHTML = `<span><b>${esc(member(s.from_id).name)}</b> paid <b>${esc(member(s.to_id).name)}</b> ${fmt(s.amount_cents / 100)}, ${shortDay(parseD(s.date))}</span><button aria-label="Remove payment">✕</button>`;
        li.querySelector("button").onclick = async () => {
          if (!(await ask("Remove this payment?", "The balance will go back to what it was before.", "Remove"))) return;
          try { await api("/api/settlements/" + s.id, { method: "DELETE" }); await loadNest(); } catch (e) { toast(e.message); }
        };
        sh.appendChild(li);
      });
      drawFilters();
      if (!searching()) {
        $("allTitle").textContent = "Everything this month";
        const l = $("list"); l.innerHTML = "";
        if (!all.length) l.innerHTML = `<li class="empty" style="justify-content:center;border:0">Nothing logged for ${esc(monthName(MONTH))}.</li>`;
        all.forEach((e) => l.appendChild(entryLi(e)));
      }
      $("mailBills").checked = !!ME.mail?.bills; $("mailStreak").checked = !!ME.mail?.streak; $("mailWeekly").checked = !!ME.mail?.weekly;
      ["mailBills", "mailStreak", "mailWeekly"].forEach((id) => ($(id).disabled = !ME.verified));
      $("mailHint").hidden = !!ME.verified;
      drawLangPickers();

      $("inviteTitle").textContent = { solo: "Invite someone (optional)", couple: "Invite your partner", family: "Invite your family" }[KIND()];
      $("inviteCode").textContent = prettyCode(NEST.invite_code);
      $("inviteLink").textContent = inviteUrl();
      $("shareInvite").hidden = !navigator.share;
      if (document.activeElement !== $("nestName")) $("nestName").value = NEST.name;
      const ks = $("kindSet"); ks.innerHTML = "";
      [["solo", "🐰", "Just me"], ["couple", "🐰🐻", "Couple"], ["family", "🐰🐻🐥", "Family"]].forEach(([id, e, n]) => {
        const b = document.createElement("button"); b.type = "button"; b.innerHTML = `<b>${e}</b>${n}`;
        b.setAttribute("aria-pressed", KIND() === id ? "true" : "false");
        b.onclick = async () => { NEST.kind = id; render(); try { await api("/api/nest", { method: "PATCH", body: { kind: id } }); } catch (err) { toast(err.message); } };
        ks.appendChild(b);
      });
      const mm = $("members"); mm.innerHTML = "";
      MEMBERS.forEach((m) => {
        const r = document.createElement("div"); r.className = "mem";
        r.innerHTML = `<span class="face" style="background:${esc(m.color)}">${esc(m.emoji)}</span><span class="nm">${esc(m.name)}${m.id === ME.id ? " (you)" : ""}</span>`;
        if (m.id === ME.id) { const b = document.createElement("button"); b.className = "small"; b.textContent = "Edit"; b.onclick = openMe; r.appendChild(b); }
        mm.appendChild(r);
      });
      drawSwatches($("swatches"));
      $("signedAs").textContent = "Signed in as " + ME.email;
    }
  }

  // ---------- plan: budgets ----------
  function renderPlan() {
    const by = spentByCat(), box = $("budgets"), cats = Object.keys(BUDGETS);
    if (!cats.length) {
      box.innerHTML = `<p class="empty" style="margin:0;padding:4px 0 10px">Give each category a monthly limit, like $400 for groceries. We'll warn you before you go over.</p><button class="small" id="budStart">Set budgets</button>`;
      $("budStart").onclick = openBudgets;
    } else {
      const totL = cats.reduce((s, c) => s + BUDGETS[c], 0), totS = cats.reduce((s, c) => s + (by[c] || 0), 0);
      box.innerHTML = `<div class="bud"><div class="l"><span>All budgets</span><small class="${totS > totL ? "over" : ""}">${fmt(totS)} of ${fmt(totL)}</small></div>
        <div class="trk"><i class="${totS > totL ? "over" : totS > totL * 0.8 ? "warn" : ""}" style="width:${Math.min(100, (totS / totL) * 100)}%"></i></div></div>` +
        cats.map((c) => ({ c, lim: BUDGETS[c], sp: by[c] || 0 })).sort((a, b) => b.sp / b.lim - a.sp / a.lim).map((x) => {
          const r = x.sp / x.lim;
          return `<div class="bud"><div class="l"><span>${catOf(x.c).e} ${esc(catOf(x.c).n)}</span><small class="${r > 1 ? "over" : ""}">${r > 1 ? "Over by " + fmt(x.sp - x.lim) : fmt(x.lim - x.sp) + " left of " + fmt(x.lim)}</small></div>
            <div class="trk"><i class="${r > 1 ? "over" : r > 0.8 ? "warn" : ""}" style="width:${Math.min(100, r * 100)}%"></i></div></div>`;
        }).join("");
    }
    renderCalendar();
    // bills list
    const bl = $("bills"); bl.innerHTML = "";
    if (!RECUR.length) bl.innerHTML = `<li class="empty" style="justify-content:center;border:0">Rent, subscriptions, paychecks. Add them once.</li>`;
    RECUR.forEach((r) => {
      const isIn = r.type === "income", n = nextOcc(r);
      const li = document.createElement("li"); li.className = "clickable";
      li.innerHTML = `<div class="ic" style="${isIn ? "background:var(--mint-t)" : ""}">${isIn ? "💰" : catOf(r.category).e}</div>
        <div class="mid"><div class="t">${esc(r.label)}</div><div class="s">${FREQ_NAME[r.freq]}${n ? ", next " + shortDay(n) : ""}, ${esc(member(r.member_id).name)}</div></div>
        <div class="amt ${isIn ? "in" : ""}">${isIn ? "+" : ""}${fmt(r.amount_cents / 100)}</div>`;
      li.onclick = () => openEditRecurring(r);
      bl.appendChild(li);
    });
    renderGoals();
    renderDebts();
  }
  function openBudgets() {
    const box = $("budgetEdit"); box.innerHTML = "";
    CATS.forEach((c) => {
      const l = document.createElement("label");
      l.innerHTML = `${c.e} <span>${esc(c.n)}</span><input type="number" inputmode="decimal" min="0" step="1" data-cat="${c.id}" placeholder="No limit">`;
      l.querySelector("input").value = BUDGETS[c.id] ?? "";
      box.appendChild(l);
    });
    $("bdErr").textContent = ""; $("budgetDlg").showModal();
  }
  $("editBudgets").onclick = openBudgets;
  $("bdCancel").onclick = () => $("budgetDlg").close();
  $("bdSave").onclick = async () => {
    const items = [...document.querySelectorAll("#budgetEdit input")].map((i) => ({ category: i.dataset.cat, limit: parseFloat(i.value) || 0 }));
    try { await api("/api/budgets", { method: "PUT", body: { items } }); $("budgetDlg").close(); await loadNest(); toast("Budgets saved"); }
    catch (e) { $("bdErr").textContent = e.message; }
  };

  // ---------- plan: bill calendar ----------
  function renderCalendar() {
    const [y, m] = MONTH.split("-").map(Number), first = new Date(y, m - 1, 1), last = new Date(y, m, 0);
    const byDay = {};
    RECUR.forEach((r) => occurrences(r, first, last).forEach((d) => {
      (byDay[d.getDate()] = byDay[d.getDate()] || []).push({ r, d, paid: isLogged(r, d) });
    }));
    const box = $("cal"); box.innerHTML = [0, 1, 2, 3, 4, 5, 6].map((i) => `<div class="wd">${new Date(2026, 1, 1 + i).toLocaleDateString(LOCALE, { weekday: "narrow" })}</div>`).join("");
    for (let i = 0; i < first.getDay(); i++) box.insertAdjacentHTML("beforeend", '<button class="blank" tabindex="-1" aria-hidden="true"></button>');
    const t = today();
    if (calSel && calSel.slice(0, 7) !== MONTH) calSel = null;
    for (let d = 1; d <= last.getDate(); d++) {
      const ds = `${MONTH}-${pad(d)}`, items = byDay[d] || [];
      const b = document.createElement("button");
      b.className = ds === t ? "today" : ""; b.setAttribute("aria-pressed", calSel === ds ? "true" : "false");
      b.setAttribute("aria-label", `${d}${items.length ? ", " + items.map((x) => x.r.label).join(", ") : ""}`);
      b.innerHTML = `${d}<span class="dots">${items.slice(0, 3).map((x) => `<i class="${x.r.type === "income" ? "in" : ""}" style="${x.paid ? "opacity:.35" : ""}"></i>`).join("")}</span>`;
      b.onclick = () => { calSel = calSel === ds ? null : ds; renderCalendar(); };
      box.appendChild(b);
    }
    const dayBox = $("calDay");
    if (!calSel) { dayBox.innerHTML = `<p class="hint" style="margin:0">Tap a day to see what's due. Pink dots are bills, green are paydays.</p>`; return; }
    const items = byDay[+calSel.slice(8)] || [];
    dayBox.innerHTML = `<p class="hint" style="margin:0 0 4px">${dayName(parseD(calSel))}</p>` + (items.length ? items.map((x) =>
      `<div><span>${x.r.type === "income" ? "💰" : catOf(x.r.category).e} ${esc(x.r.label)}</span><span>${x.r.type === "income" ? "+" : ""}${fmt(x.r.amount_cents / 100)} · ${x.paid ? "Done ✓" : x.d < parseD(t) ? "Overdue" : x.r.type === "income" ? "Expected" : "Due"}</span></div>`).join("")
      : `<p class="hint" style="margin:0">Nothing due this day.</p>`);
  }

  // ---------- plan: savings goals ----------
  function renderGoals() {
    const box = $("goals");
    if (!GOALS.length) { box.innerHTML = `<p class="empty" style="margin:0;padding:14px 0">Save for a trip, a ring, or a rainy day. Tap New goal to start.</p>`; return; }
    box.innerHTML = "";
    GOALS.forEach((g) => {
      const saved = g.saved_cents / 100, target = g.target_cents / 100, pct = target ? Math.min(100, (saved / target) * 100) : 0;
      const el = document.createElement("div"); el.className = "goal";
      el.innerHTML = `<span class="em">${esc(g.emoji)}</span><div class="mid"><div class="t"><span>${esc(g.name)}</span><small>${Math.round(pct)}%</small></div>
        <div class="s">${fmt(saved)} of ${fmt(target)}${pct >= 100 ? " · reached ♡" : ""}</div><div class="trk"><i style="width:${pct}%"></i></div></div>`;
      el.onclick = () => openGoal(g);
      box.appendChild(el);
    });
  }
  let goalOpen = null, goalEmoji = GOAL_EMOJIS[0];
  function drawGoalView() {
    const g = GOALS.find((x) => x.id === goalOpen?.id); if (!g) { $("goalDlg").close(); return; }
    goalOpen = g;
    $("gdTitle").textContent = `${g.emoji} ${g.name}`;
    $("gdProg").textContent = `${fmt(g.saved_cents / 100)} of ${fmt(g.target_cents / 100)} saved`;
    const h = $("gdHist"); h.innerHTML = "";
    JAR.filter((j) => j.goal_id === g.id).slice(0, 8).forEach((j) => {
      const li = document.createElement("li"), inn = j.amount_cents > 0;
      const when = new Date(j.created_at * 1000).toLocaleDateString(LOCALE, { month: "short", day: "numeric" });
      li.innerHTML = `<span><b>${esc(member(j.member_id).name)}</b> ${inn ? "added" : "took out"} ${fmt(Math.abs(j.amount_cents) / 100)}, ${when}</span><button aria-label="Remove">✕</button>`;
      li.querySelector("button").onclick = async () => { try { await api("/api/jar/" + j.id, { method: "DELETE" }); await loadNest(); drawGoalView(); } catch (e) { toast(e.message); } };
      h.appendChild(li);
    });
  }
  function openGoal(g) { goalOpen = g; $("gdView").hidden = false; $("gdForm").hidden = true; $("gdAmt").value = ""; drawGoalView(); $("goalDlg").showModal(); }
  function drawGoalEmojis() {
    const r = $("gEmojis"); r.innerHTML = "";
    GOAL_EMOJIS.forEach((e) => { const b = document.createElement("button"); b.type = "button"; b.textContent = e; b.setAttribute("aria-pressed", e === goalEmoji ? "true" : "false"); b.onclick = () => { goalEmoji = e; drawGoalEmojis(); }; r.appendChild(b); });
  }
  function openGoalForm(g) {
    goalOpen = g || null; $("gdView").hidden = true; $("gdForm").hidden = false;
    $("gdTitle").textContent = g ? "Edit goal" : "New savings goal";
    $("gName").value = g ? g.name : ""; $("gTarget").value = g ? g.target_cents / 100 : ""; goalEmoji = g ? g.emoji : GOAL_EMOJIS[0];
    $("gDelete").hidden = !g; $("gErr").textContent = ""; drawGoalEmojis();
    if (!$("goalDlg").open) $("goalDlg").showModal();
  }
  $("addGoal").onclick = () => openGoalForm(null);
  $("gdEdit").onclick = () => openGoalForm(goalOpen);
  $("gdClose").onclick = () => $("goalDlg").close();
  $("gCancel").onclick = () => { if (goalOpen) { $("gdView").hidden = false; $("gdForm").hidden = true; drawGoalView(); } else $("goalDlg").close(); };
  $("gSave").onclick = async () => {
    const body = { name: $("gName").value, target: parseFloat($("gTarget").value), emoji: goalEmoji };
    try {
      if (goalOpen) await api("/api/goals/" + goalOpen.id, { method: "PATCH", body });
      else await api("/api/goals", { method: "POST", body });
      $("goalDlg").close(); await loadNest(); toast("Goal saved");
    } catch (e) { $("gErr").textContent = e.message; }
  };
  $("gDelete").onclick = async () => {
    const g = goalOpen; $("goalDlg").close();
    if (!(await ask(`Delete ${g.name}?`, "Its savings history goes too. The money you moved stays wherever you put it.", "Delete"))) return;
    try { await api("/api/goals/" + g.id, { method: "DELETE" }); await loadNest(); } catch (e) { toast(e.message); }
  };
  async function goalMove(direction) {
    const v = parseFloat($("gdAmt").value);
    if (!(v > 0)) { $("gdAmt").focus(); return; }
    try {
      const res = await api("/api/jar", { method: "POST", body: { goal_id: goalOpen.id, amount: v, direction } });
      $("gdAmt").value = ""; await loadNest(); drawGoalView();
      rewardToast(res.reward, direction === "in" ? "Added to " + goalOpen.name : "Taken out");
      const g = GOALS.find((x) => x.id === goalOpen.id);
      if (g && direction === "in" && g.saved_cents >= g.target_cents && g.saved_cents - v * 100 < g.target_cents) setTimeout(() => toast(`🍯 You reached ${g.name}!`), 2200);
    } catch (e) { toast(e.message); }
  }
  $("gdIn").onclick = () => goalMove("in");
  $("gdOut").onclick = () => goalMove("out");

  // ---------- plan: debts ----------
  let debtStrat = store.get("hb-debt-strat") || "snowball";
  function payoffPlan(extra) {
    const ds = DEBTS.map((d) => ({ id: d.id, bal: Math.max(0, (d.start_cents - d.paid_cents) / 100), r: d.apr_bp / 10000 / 12, min: d.min_cents / 100 })).filter((d) => d.bal > 0.005);
    const order = [...ds].sort(debtStrat === "avalanche" ? (a, b) => b.r - a.r || a.bal - b.bal : (a, b) => a.bal - b.bal).map((d) => d.id);
    if (!ds.length) return { months: 0, order, done: {} };
    const budget = ds.reduce((s, d) => s + d.min, 0) + extra, done = {};
    if (budget <= 0) return { months: null, order, done };
    let m = 0;
    while (ds.some((d) => d.bal > 0.005) && m < 600) {
      m++;
      ds.forEach((d) => { if (d.bal > 0.005) d.bal += d.bal * d.r; });
      let pool = budget;
      ds.forEach((d) => { if (d.bal > 0.005) { const p = Math.min(d.min, d.bal, pool); d.bal -= p; pool -= p; } });
      for (const id of order) { const d = ds.find((x) => x.id === id); if (d.bal > 0.005 && pool > 0) { const p = Math.min(pool, d.bal); d.bal -= p; pool -= p; } }
      ds.forEach((d) => { if (d.bal <= 0.005 && !done[d.id]) done[d.id] = m; });
    }
    return { months: m >= 600 ? null : m, order, done };
  }
  const monthsOut = (n) => { const d = new Date(); d.setMonth(d.getMonth() + n); return d.toLocaleDateString(LOCALE, { month: "short", year: "numeric" }); };
  function renderDebts() {
    const box = $("debts");
    if (!DEBTS.length) { box.innerHTML = `<p class="empty" style="margin:0;padding:4px 0">Track credit cards, car loans, or student loans and see when you'll be debt-free.</p>`; return; }
    const left = DEBTS.reduce((s, d) => s + Math.max(0, d.start_cents - d.paid_cents), 0) / 100;
    const paid = DEBTS.reduce((s, d) => s + d.paid_cents, 0) / 100;
    const extra = parseFloat(store.get("hb-debt-extra") || "0") || 0;
    const plan = payoffPlan(extra);
    box.innerHTML = `<div class="strategy"><div class="split"><button type="button" data-s="snowball" aria-pressed="${debtStrat === "snowball"}">Snowball</button><button type="button" data-s="avalanche" aria-pressed="${debtStrat === "avalanche"}">Avalanche</button></div></div>
      <p class="hint" style="margin:0 0 8px">${debtStrat === "snowball" ? "Pay the smallest balance first for quick wins." : "Pay the highest interest first to save the most money."}</p>
      <label class="extra">Extra each month $<input id="debtExtra" type="number" inputmode="decimal" min="0" step="10" value="${extra || ""}" placeholder="0"></label>
      <div class="payoff">${left <= 0 ? "Everything's paid off 🎉" : plan.months === null ? "Add minimum payments to see your debt-free date." : `<b>${fmt(left)}</b> left · debt-free around <b>${monthsOut(plan.months)}</b>`}${paid > 0 ? `<br><span style="color:var(--soft)">${fmt(paid)} paid so far</span>` : ""}</div>`;
    box.querySelectorAll("[data-s]").forEach((b) => (b.onclick = () => { debtStrat = b.dataset.s; store.set("hb-debt-strat", debtStrat); renderDebts(); }));
    $("debtExtra").onchange = (e) => { store.set("hb-debt-extra", String(parseFloat(e.target.value) || 0)); renderDebts(); };
    const sorted = [...DEBTS].sort((a, b) => {
      const ia = plan.order.indexOf(a.id), ib = plan.order.indexOf(b.id);
      return (ia < 0 ? 999 : ia) - (ib < 0 ? 999 : ib);
    });
    sorted.forEach((d, i) => {
      const rem = Math.max(0, d.start_cents - d.paid_cents) / 100, pct = d.start_cents ? Math.min(100, (d.paid_cents / d.start_cents) * 100) : 0;
      const el = document.createElement("div"); el.className = "goal debt";
      el.innerHTML = `<span class="em">${rem <= 0 ? "🎉" : "💳"}</span><div class="mid"><div class="t"><span>${rem > 0 ? `${i + 1}. ` : ""}${esc(d.name)}</span><small>${fmt(rem)} left</small></div>
        <div class="s">${(d.apr_bp / 100).toFixed(2).replace(/\.00$/, "")}% APR · min ${fmt(d.min_cents / 100)}${plan.done[d.id] ? " · paid off ~" + monthsOut(plan.done[d.id]) : ""}</div>
        <div class="trk"><i style="width:${pct}%"></i></div></div>${rem > 0 ? '<button class="mini inc">Pay</button>' : ""}`;
      el.onclick = () => openDebt(d);
      const pb = el.querySelector("button"); if (pb) pb.onclick = (ev) => { ev.stopPropagation(); openPay(d); };
      box.appendChild(el);
    });
    if (DEBTPAYS.length) {
      const h = document.createElement("ul"); h.className = "hist";
      DEBTPAYS.slice(0, 5).forEach((p) => {
        const d = DEBTS.find((x) => x.id === p.debt_id); if (!d) return;
        const li = document.createElement("li");
        li.innerHTML = `<span><b>${esc(member(p.member_id).name)}</b> paid ${fmt(p.amount_cents / 100)} on ${esc(d.name)}, ${shortDay(parseD(p.date))}</span><button aria-label="Remove payment">✕</button>`;
        li.querySelector("button").onclick = async () => {
          if (!(await ask("Remove this payment?", "It's also removed from that month's spending.", "Remove"))) return;
          try { await api("/api/debt-payments/" + p.id, { method: "DELETE" }); await loadNest(); } catch (e) { toast(e.message); }
        };
        h.appendChild(li);
      });
      box.appendChild(h);
    }
  }
  let debtOpen = null;
  function openDebt(d) {
    debtOpen = d || null;
    $("ddTitle").textContent = d ? "Edit debt" : "Add a debt";
    $("dName").value = d ? d.name : ""; $("dBal").value = d ? d.start_cents / 100 : ""; $("dApr").value = d ? d.apr_bp / 100 : ""; $("dMin").value = d ? d.min_cents / 100 : "";
    $("dHint").textContent = d ? "Balance here is where you started. Payments you log are taken off it." : "For a debt you've already been paying, enter what you owe today.";
    $("dDelete").hidden = !d; $("dErr").textContent = ""; $("debtDlg").showModal();
  }
  $("addDebt").onclick = () => openDebt(null);
  $("dCancel").onclick = () => $("debtDlg").close();
  $("dSave").onclick = async () => {
    const body = { name: $("dName").value, balance: parseFloat($("dBal").value), apr: parseFloat($("dApr").value) || 0, min: parseFloat($("dMin").value) || 0 };
    try {
      if (debtOpen) await api("/api/debts/" + debtOpen.id, { method: "PATCH", body });
      else await api("/api/debts", { method: "POST", body });
      $("debtDlg").close(); await loadNest(); toast("Debt saved");
    } catch (e) { $("dErr").textContent = e.message; }
  };
  $("dDelete").onclick = async () => {
    const d = debtOpen; $("debtDlg").close();
    if (!(await ask(`Delete ${d.name}?`, "Its payment history goes too. Payments stay in your spending.", "Delete"))) return;
    try { await api("/api/debts/" + d.id, { method: "DELETE" }); await loadNest(); } catch (e) { toast(e.message); }
  };
  let payOpen = null, payWho = null;
  function drawPayWho() {
    const w = $("pdWho"); w.innerHTML = "";
    MEMBERS.forEach((m) => { const b = document.createElement("button"); b.type = "button"; b.innerHTML = `<i style="background:${esc(m.color)}">${esc(m.emoji)}</i>${esc(m.name)}`; b.setAttribute("aria-pressed", m.id === payWho ? "true" : "false"); b.onclick = () => { payWho = m.id; drawPayWho(); }; w.appendChild(b); });
  }
  function openPay(d) {
    payOpen = d; payWho = ME.id;
    $("pdText").textContent = `${d.name} · ${fmt(Math.max(0, d.start_cents - d.paid_cents) / 100)} left`;
    $("pdAmt").value = d.min_cents ? (d.min_cents / 100).toFixed(2) : ""; $("pdErr").textContent = "";
    drawPayWho(); $("payDlg").showModal();
  }
  $("pdCancel").onclick = () => $("payDlg").close();
  $("pdSave").onclick = async () => {
    const amount = parseFloat($("pdAmt").value);
    if (!(amount > 0)) { $("pdErr").textContent = "Enter the amount you paid."; return; }
    try {
      const res = await api(`/api/debts/${payOpen.id}/pay`, { method: "POST", body: { amount, member_id: payWho, date: today() } });
      $("payDlg").close(); await loadNest(); rewardToast(res.reward, "Payment logged");
      const d = DEBTS.find((x) => x.id === payOpen.id);
      if (d && d.paid_cents >= d.start_cents) setTimeout(() => toast(`🎉 ${d.name} is paid off!`), 2200);
    } catch (e) { $("pdErr").textContent = e.message; }
  };

  // ---------- stats ----------
  async function loadYear() {
    try { YDATA = await api("/api/year?year=" + YEAR); } catch (e) { YDATA = { entries: [], jar: [] }; toast(e.message); }
    if (screen === "stats") renderStats();
  }
  $("prevY").onclick = () => { YEAR--; YDATA = null; renderStats(); loadYear(); };
  $("nextY").onclick = () => { YEAR++; YDATA = null; renderStats(); loadYear(); };
  function renderStats() {
    renderBurrow();
    $("yearLbl").textContent = YEAR;
    const ents = YDATA ? YDATA.entries : [];
    const inc = Array(12).fill(0), out = Array(12).fill(0), yc = {};
    ents.forEach((e) => {
      const m = +e.date.slice(5, 7) - 1, a = e.amount_cents / 100;
      if (e.type === "income") inc[m] += a; else { out[m] += a; yc[e.category] = (yc[e.category] || 0) + a; }
    });
    const ti = inc.reduce((a, b) => a + b, 0), to = out.reduce((a, b) => a + b, 0);
    $("yIn").textContent = fmt(ti); $("yOut").textContent = fmt(to); $("yKeep").textContent = ti ? Math.round(((ti - to) / ti) * 100) + "%" : "–";
    // chart
    const W = 340, H = 150, top = Math.max(1, ...inc, ...out), gw = W / 12, bw = 9;
    let svg = `<svg viewBox="0 0 ${W} ${H + 18}" role="img" aria-label="Earned and spent by month">`;
    for (let i = 0; i < 12; i++) {
      const x = i * gw + gw / 2, hi = (inc[i] / top) * H, ho = (out[i] / top) * H, name = new Date(YEAR, i, 1).toLocaleDateString(LOCALE, { month: "short" });
      svg += `<rect x="${x - bw - 1}" y="${H - hi}" width="${bw}" height="${Math.max(hi, 1.5)}" rx="3" fill="var(--mint)" opacity="${inc[i] ? 1 : 0.25}"><title>${name}: earned ${fmt(inc[i])}</title></rect>`;
      svg += `<rect x="${x + 1}" y="${H - ho}" width="${bw}" height="${Math.max(ho, 1.5)}" rx="3" fill="var(--pink)" opacity="${out[i] ? 1 : 0.25}"><title>${name}: spent ${fmt(out[i])}</title></rect>`;
      svg += `<text x="${x}" y="${H + 14}" text-anchor="middle" font-size="9" font-weight="700" fill="var(--soft)">${LANG === "zh" ? i + 1 : name.slice(0, 1).toUpperCase()}</text>`;
    }
    $("yChart").innerHTML = svg + "</svg>";
    // 50/30/20 for the selected month
    $("ruleMonth").textContent = monthName(MONTH);
    const mInc = ENTRIES.filter((e) => e.type === "income").reduce((s, e) => s + e.amount, 0);
    const by = spentByCat(), needs = NEEDS.reduce((s, c) => s + (by[c] || 0), 0), wants = WANTS.reduce((s, c) => s + (by[c] || 0), 0);
    if (!mInc) $("rule").innerHTML = `<p class="empty" style="margin:0">Add this month's income to see how your money splits between needs, wants, and savings.</p>`;
    else {
      const sav = Math.max(0, mInc - needs - wants);
      $("rule").innerHTML = [["Needs", needs, 50, "#9BB8FF", "rent, groceries, bills, car, debt"], ["Wants", wants, 30, "var(--pink)", "eating out, fun, subscriptions"], ["Savings", sav, 20, "var(--mint)", "what's left over"]]
        .map(([n, v, goal, c, d]) => { const p = (v / mInc) * 100; return `<div class="rule"><div class="l"><span>${n} <small>${d}</small></span><span>${Math.round(p)}% <small>/ ${goal}%</small></span></div>
          <div class="trk"><i style="width:${Math.min(100, p)}%;background:${c}"></i><b style="left:${goal}%"></b></div></div>`; }).join("") +
        `<p class="hint">The line marks the classic 50/30/20 target.</p>`;
    }
    // where it went (month) + year categories
    $("barsMonth").textContent = monthName(MONTH);
    const bars = (el, data) => {
      const rows = CATS.filter((c) => data[c.id]).sort((a, b) => data[b.id] - data[a.id]).slice(0, 8), mx = Math.max(1, ...rows.map((c) => data[c.id]));
      el.innerHTML = rows.length ? rows.map((c) => `<div class="bar"><div class="l"><span>${c.e} ${c.n}</span><span>${fmt(data[c.id])}</span></div><div class="trk"><i style="width:${(data[c.id] / mx) * 100}%;background:${c.c}"></i></div></div>`).join("")
        : `<p class="empty" style="margin:0">No spending yet.</p>`;
    };
    bars($("bars"), by); bars($("yCats"), yc);
  }
  $("exportCsv").onclick = () => {
    if (!YDATA) return;
    const q = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
    const rows = [["Date", "Type", "Category", "Description", "Who", "Amount", "Split", "Private"]].concat(YDATA.entries.map((e) =>
      [e.date, tr(e.type === "income" ? "Income" : "Expense"), tr(e.type === "income" ? "Income" : catOf(e.category).n), e.label, member(e.member_id).name,
       ((e.type === "income" ? 1 : -1) * e.amount_cents / 100).toFixed(2), e.shared ? "Yes" : "No", e.private ? "Yes" : "No"]));
    const blob = new Blob(["\ufeff" + rows.map((r) => r.map(q).join(",")).join("\r\n")], { type: "text/csv;charset=utf-8" });
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = `honeybun-${YEAR}.csv`;
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  };

  // ---------- add / edit form ----------
  function resetForm(opts = {}) {
    mode = opts.type || "expense"; cat = "groc"; who = ME.id; shared = MEMBERS.length > 1; splitMode = "equal";
    $("amt").value = ""; $("lbl").value = ""; $("splitVal").value = ""; $("priv").checked = false;
    $("repeat").value = opts.repeat || ""; $("dt").value = today(); $("paidNow").checked = false; $("err").textContent = "";
  }
  function openAdd(opts) { editing = null; resetForm(opts); show("add"); setTimeout(() => $("amt").focus(), 60); }
  function fillForm(x, isRec) {
    mode = x.type; cat = x.category || "groc"; who = x.member_id; shared = !!x.shared; splitMode = x.split_mode || "equal";
    $("amt").value = (isRec ? x.amount_cents / 100 : x.amount).toFixed(2);
    $("lbl").value = x.label;
    $("splitVal").value = x.split_mode === "owed" ? (x.split_value / 100).toFixed(2) : x.split_mode === "percent" ? x.split_value : "";
    $("priv").checked = !!x.private;
    $("dt").value = isRec ? toS(nextOcc(x) || parseD(x.anchor_date)) : x.date;
    $("repeat").value = isRec ? x.freq : "";
    $("err").textContent = "";
  }
  function openEditEntry(e) {
    if (e.pending) { toast("This will sync when you're back online. Edit it after."); return; } editing = { kind: "entry", x: e }; fillForm(e, false); show("add"); }
  function openEditRecurring(r) { editing = { kind: "recurring", x: r }; fillForm(r, true); show("add"); }
  $("cancelEdit").onclick = () => { const back = editing?.kind === "recurring" ? "plan" : "home"; editing = null; show(back); };
  $("addBill").onclick = () => openAdd({ repeat: "monthly" });

  function renderForm() {
    const isInc = mode === "income", rep = $("repeat").value, editingRec = editing?.kind === "recurring";
    $("editBar").hidden = !editing;
    $("editTitle").textContent = editingRec ? (isInc ? "Edit payday" : "Edit bill") : "Edit entry";
    document.querySelectorAll("#scr-add .tabs button").forEach((b) => b.setAttribute("aria-selected", b.dataset.t === mode ? "true" : "false"));

    const c = $("cats"); c.innerHTML = "";
    CATS.forEach((k) => {
      const b = document.createElement("button"); b.type = "button"; b.innerHTML = `<b>${k.e}</b>${k.n}`;
      b.setAttribute("aria-pressed", k.id === cat ? "true" : "false"); b.onclick = () => { cat = k.id; renderForm(); }; c.appendChild(b);
    });
    const w = $("whos"); w.innerHTML = "";
    if (!MEMBERS.some((m) => m.id === who)) who = ME.id;
    MEMBERS.forEach((m) => {
      const b = document.createElement("button"); b.type = "button";
      b.innerHTML = `<i style="background:${esc(m.color)}">${esc(m.emoji)}</i>${esc(m.name)}`;
      b.setAttribute("aria-pressed", m.id === who ? "true" : "false"); b.onclick = () => { who = m.id; renderForm(); }; w.appendChild(b);
    });
    $("catField").hidden = isInc;
    $("lblLabel").textContent = rep || editingRec ? "Name" : "Note (optional)";
    $("lbl").placeholder = isInc ? "Paycheck" : rep ? "Rent" : "Date night tacos";
    $("whoLabel").textContent = isInc ? "Who gets paid?" : "Who pays?";

    // split
    const canSplit = !isInc && MEMBERS.length > 1;
    $("splitField").hidden = !canSplit;
    $("spShared").setAttribute("aria-pressed", shared ? "true" : "false");
    $("spMine").setAttribute("aria-pressed", shared ? "false" : "true");
    $("splitOpts").hidden = !shared;
    document.querySelectorAll("#splitModes button").forEach((b) => b.setAttribute("aria-pressed", b.dataset.mode === splitMode ? "true" : "false"));
    const o = others(who), payer = member(who), oName = o.length === 1 ? o[0].name : "Everyone else";
    $("splitValWrap").hidden = splitMode === "equal";
    if (splitMode === "percent") {
      $("splitPre").textContent = payer.name + " covers"; $("splitPost").textContent = "%";
      $("splitVal").step = "1"; $("splitVal").placeholder = "70";
      const v = parseFloat($("splitVal").value);
      $("splitHint").textContent = v >= 0 && v <= 100 ? `${oName} ${o.length === 1 ? "covers" : "cover"} ${100 - v}%${o.length > 1 ? ", split between them" : ""}.` : "";
    } else if (splitMode === "owed") {
      $("splitPre").textContent = oName + (o.length === 1 ? " owes $" : " owe $"); $("splitPost").textContent = o.length > 1 ? "total" : "";
      $("splitVal").step = "0.01"; $("splitVal").placeholder = "40";
      $("splitHint").textContent = `Use this when ${payer.name} paid and just needs part of it back.`;
    } else $("splitHint").textContent = MEMBERS.length === 2 ? "Each of you covers half." : "Everyone covers the same amount.";

    // privacy: only for your own, unshared, non-repeating entries
    $("privWrap").hidden = !(who === ME.id && (!shared || !canSplit) && !rep && !editingRec);

    // repeating
    $("repeatField").hidden = editing?.kind === "entry";
    $("dtLabel").textContent = rep ? (editingRec ? "Next date" : "Next (or last) date") : "Date";
    $("paidNowWrap").hidden = !rep || editingRec;
    $("paidNowTxt").textContent = isInc ? "Already got this one" : "Already paid this one";
    $("delRecWrap").hidden = !editingRec;

    $("goBtn").textContent = editing ? "Save changes" : rep ? (isInc ? "Add payday" : "Add bill") : isInc ? "Add income" : "Add expense";
    $("goBtn").classList.toggle("inc", isInc);
  }
  document.querySelectorAll("#scr-add .tabs button").forEach((b) => (b.onclick = () => { mode = b.dataset.t; $("err").textContent = ""; renderForm(); }));
  $("spShared").onclick = () => { shared = true; renderForm(); };
  $("spMine").onclick = () => { shared = false; renderForm(); };
  document.querySelectorAll("#splitModes button").forEach((b) => (b.onclick = () => { splitMode = b.dataset.mode; $("splitVal").value = ""; renderForm(); if (splitMode !== "equal") $("splitVal").focus(); }));
  $("splitVal").oninput = () => { if (splitMode === "percent") renderForm(); };
  $("repeat").onchange = () => { $("paidNow").checked = $("dt").value <= today(); renderForm(); };
  $("dt").onchange = () => { if ($("repeat").value && !editing) $("paidNow").checked = $("dt").value <= today(); };

  $("goBtn").onclick = async () => {
    const amount = parseFloat($("amt").value);
    if (!(amount > 0)) { $("err").textContent = "Type an amount above $0 first."; $("amt").focus(); return; }
    const rep = $("repeat").value, isShared = mode === "expense" && shared && MEMBERS.length > 1;
    let split_value = null;
    if (isShared && splitMode !== "equal") {
      split_value = parseFloat($("splitVal").value);
      if (splitMode === "percent" && !(split_value >= 0 && split_value <= 100)) { $("err").textContent = "Enter a percent from 0 to 100."; $("splitVal").focus(); return; }
      if (splitMode === "owed" && !(split_value > 0 && split_value <= amount)) { $("err").textContent = "The amount owed has to be more than $0 and no more than the total."; $("splitVal").focus(); return; }
    }
    const date = $("dt").value || today();
    const label = $("lbl").value.trim() || tr(mode === "income" ? "Paycheck" : CATS.find((c) => c.id === cat).n);
    const body = {
      type: mode, amount, label, category: cat, member_id: who, shared: isShared,
      split_mode: isShared ? splitMode : null, split_value, private: $("priv").checked && !$("privWrap").hidden, date,
    };
    busy($("goBtn"), true); $("err").textContent = "";
    try {
      if (editing?.kind === "entry") {
        await api("/api/entries/" + editing.x.id, { method: "PATCH", body });
        MONTH = ym(date); editing = null; await loadNest(); toast("Changes saved"); show("home");
      } else if (editing?.kind === "recurring") {
        if (!rep) { $("err").textContent = "Pick how often it repeats."; return; }
        await api("/api/recurring/" + editing.x.id, { method: "PATCH", body: { ...body, freq: rep } });
        editing = null; await loadNest(); toast("Saved"); show("plan");
      } else if (rep) {
        const res = await api("/api/recurring", { method: "POST", body: { ...body, freq: rep, log_now: $("paidNow").checked } });
        await loadNest(); rewardToast(res.reward, mode === "income" ? "Payday added" : "Bill added"); show("plan");
      } else {
        const res = await api("/api/entries", { method: "POST", body });
        MONTH = ym(date); await loadNest();
        if (res.queued) toast("Saved offline. It'll sync when you're back."); else rewardToast(res.reward, mode === "income" ? "Income added" : "Expense added");
        show("home"); bunnyHop();
      }
    } catch (e) { $("err").textContent = e.message; }
    finally { busy($("goBtn"), false); }
  };
  $("delRec").onclick = async () => {
    const r = editing?.x; if (!r) return;
    if (!(await ask(`Delete ${r.label}?`, "It stops showing up as due. Anything already logged stays.", "Delete"))) return;
    try { await api("/api/recurring/" + r.id, { method: "DELETE" }); editing = null; await loadNest(); toast("Deleted"); show("plan"); }
    catch (e) { toast(e.message); }
  };

  // ---------- settle up ----------
  let settling = null;
  function openSettle(p) {
    settling = p;
    $("sdText").textContent = `${p.from.name} paid ${p.to.name} back.`;
    $("sdAmt").value = p.amount.toFixed(2); $("sdErr").textContent = "";
    $("settleDlg").showModal();
  }
  $("sdCancel").onclick = () => $("settleDlg").close();
  $("sdSave").onclick = async () => {
    const amount = parseFloat($("sdAmt").value);
    if (!(amount > 0)) { $("sdErr").textContent = "Enter the amount that was paid."; return; }
    try {
      const res = await api("/api/settlements", { method: "POST", body: { from_id: settling.from.id, to_id: settling.to.id, amount, date: today() } });
      $("settleDlg").close(); await loadNest(); rewardToast(res.reward, "Marked as paid ♡");
    } catch (e) { $("sdErr").textContent = e.message; }
  };

  // ---------- edit yourself ----------
  let pickE, pickC;
  function drawPick() {
    const ep = $("emojiPick"); ep.innerHTML = "";
    EMOJIS.forEach((e) => { const b = document.createElement("button"); b.type = "button"; b.textContent = e; b.setAttribute("aria-pressed", e === pickE ? "true" : "false"); b.onclick = () => { pickE = e; drawPick(); }; ep.appendChild(b); });
    const cp = $("colorPick"); cp.innerHTML = "";
    COLORS.forEach((c) => { const b = document.createElement("button"); b.type = "button"; b.style.background = c; b.setAttribute("aria-label", "Color"); b.setAttribute("aria-pressed", c === pickC ? "true" : "false"); b.onclick = () => { pickC = c; drawPick(); }; cp.appendChild(b); });
  }
  function openMe() {
    const m = meMember(); if (!m) return;
    $("mName").value = m.name; pickE = m.emoji; pickC = m.color; $("mErr").textContent = "";
    drawPick(); $("memberDlg").showModal();
  }
  $("mCancel").onclick = () => $("memberDlg").close();
  $("mSave").onclick = async () => {
    const name = $("mName").value.trim(); if (!name) { $("mName").focus(); return; }
    try { await api("/api/me", { method: "PATCH", body: { name, emoji: pickE, color: pickC } }); $("memberDlg").close(); await loadNest(); }
    catch (e) { $("mErr").textContent = e.message; }
  };

  // ---------- password change ----------
  $("changePw").onclick = () => { $("pwCur").value = ""; $("pwNew").value = ""; $("pwErr").textContent = ""; $("pwDlg").showModal(); };
  $("pwCancel").onclick = () => $("pwDlg").close();
  $("pwSave").onclick = async () => {
    if ($("pwNew").value.length < 8) { $("pwErr").textContent = "Use a password with at least 8 characters."; return; }
    try {
      await api("/api/password/change", { method: "POST", body: { current: $("pwCur").value, password: $("pwNew").value } });
      $("pwDlg").close(); toast("Password changed. Other devices were logged out.");
    } catch (e) { $("pwErr").textContent = e.message; }
  };

  // ---------- password change ----------
  $("changePw").onclick = () => { $("pwCur").value = ""; $("pwNew").value = ""; $("pwErr").textContent = ""; $("pwDlg").showModal(); };
  $("pwCancel").onclick = () => $("pwDlg").close();
  $("pwSave").onclick = async () => {
    if ($("pwNew").value.length < 8) { $("pwErr").textContent = "Use a password with at least 8 characters."; return; }
    try {
      await api("/api/password/change", { method: "POST", body: { current: $("pwCur").value, password: $("pwNew").value } });
      $("pwDlg").close(); toast("Password changed. Other devices were logged out.");
    } catch (e) { $("pwErr").textContent = e.message; }
  };

  // ---------- settings ----------
  function drawSwatches(box) {
    box.innerHTML = "";
    THEMES.forEach((t) => {
      const b = document.createElement("button"); b.type = "button"; b.setAttribute("aria-pressed", NEST.accent === t.id ? "true" : "false");
      b.innerHTML = `<i style="background:${t.c}"></i>${t.n}`;
      b.onclick = async () => { NEST.accent = t.id; render(); drawSwatches(box); try { await api("/api/nest", { method: "PATCH", body: { accent: t.id } }); } catch (e) { toast(e.message); } };
      box.appendChild(b);
    });
  }
  let nameTimer;
  $("nestName").oninput = (e) => {
    NEST.name = e.target.value.trim(); render();
    clearTimeout(nameTimer);
    nameTimer = setTimeout(() => api("/api/nest", { method: "PATCH", body: { name: NEST.name } }).catch((err) => toast(err.message)), 600);
  };
  $("hiBtn").onclick = () => { show("us"); setTimeout(() => $("setH").scrollIntoView({ behavior: "smooth" }), 40); };
  $("copyInvite").onclick = async () => { try { await navigator.clipboard.writeText(inviteUrl()); toast("Link copied"); } catch { toast("Couldn't copy. Press and hold the link instead."); } };
  $("shareInvite").onclick = async () => { try { await navigator.share({ title: "Join my Honeybun budget", text: "Join my budget on Honeybun 🐰", url: inviteUrl() }); } catch {} };
  $("newCode").onclick = async () => {
    if (!(await ask("Make a new code?", "The old code and link will stop working. People already in the budget stay in.", "Make new code"))) return;
    try { await api("/api/nest/invite", { method: "POST" }); await loadNest(); toast("New code ready"); } catch (e) { toast(e.message); }
  };
  $("leaveBtn").onclick = async () => {
    const alone = MEMBERS.length === 1;
    if (!(await ask("Leave this budget?", alone ? "You're the only one here, so the budget and everything in it will be deleted." : "You can rejoin later with an invite code.", "Leave"))) return;
    try { await api("/api/nest/leave", { method: "POST" }); NEST = null; filter = null; await afterAuth(); } catch (e) { toast(e.message); }
  };

  // months
  async function shift(k) {
    const [y, mo] = MONTH.split("-").map(Number); const d = new Date(y, mo - 1 + k, 1);
    MONTH = d.getFullYear() + "-" + pad(d.getMonth() + 1);
    render();
    try { await loadNest(); } catch (e) { toast(e.message); }
  }
  $("prevM").onclick = () => shift(-1);
  $("nextM").onclick = () => shift(1);
  $("seeAll").onclick = () => { show("us"); setTimeout(() => $("allH").scrollIntoView({ behavior: "smooth" }), 40); };

  // ---------- search & filters ----------
  const searching = () => !!($("q").value.trim() || $("fType").value || $("fCat").value || $("fWho").value);
  function drawFilters() {
    const fc = $("fCat");
    if (fc.options.length !== CATS.length + 1) CATS.forEach((c) => fc.add(new Option(`${c.e} ${tr(c.n)}`, c.id)));
    const fw = $("fWho"), cur = fw.value;
    while (fw.options.length > 1) fw.remove(1);
    MEMBERS.forEach((m) => fw.add(new Option(`${m.emoji} ${m.name}`, m.id)));
    fw.value = cur; fw.hidden = MEMBERS.length < 2;
  }
  let searchTimer;
  async function runSearch() {
    if (!searching()) { $("searchHint").hidden = true; render(); return; }
    const params = new URLSearchParams({ q: $("q").value.trim(), type: $("fType").value, cat: $("fCat").value, member: $("fWho").value });
    try {
      const d = await api("/api/search?" + params);
      const rows = d.entries.map((e) => ({ ...e, amount: e.amount_cents / 100, shared: !!e.shared, private: !!e.private }));
      $("allTitle").textContent = "Search results";
      const total = rows.reduce((s, e) => s + (e.type === "income" ? e.amount : -e.amount), 0);
      $("searchHint").hidden = false;
      $("searchHint").textContent = rows.length ? `${rows.length} found · net ${fmt(total)}` : "Nothing matches that.";
      const l = $("list"); l.innerHTML = "";
      rows.forEach((e) => l.appendChild(entryLi(e)));
    } catch (e) { toast(e.message); }
  }
  $("q").oninput = () => { clearTimeout(searchTimer); searchTimer = setTimeout(runSearch, 300); };
  ["fType", "fCat", "fWho"].forEach((id) => ($(id).onchange = runSearch));

  // ---------- email, account & data ----------
  $("resendVerify").onclick = async () => {
    try { const r = await api("/api/email/resend", { method: "POST" }); if (r.already) { ME.verified = true; render(); toast("Your email is already confirmed ♡"); } else toast("Sent! Check your inbox."); }
    catch (e) { toast(e.message); }
  };
  [["mailBills", "mail_bills", "bills"], ["mailStreak", "mail_streak", "streak"], ["mailWeekly", "mail_weekly", "weekly"]].forEach(([id, key, k]) => {
    $(id).onchange = async (ev) => {
      const on = ev.target.checked;
      try { await api("/api/me", { method: "PATCH", body: { [key]: on } }); ME.mail = { ...(ME.mail || {}), [k]: on }; toast(on ? "Reminder on" : "Reminder off"); }
      catch (e) { ev.target.checked = !on; toast(e.message); }
    };
  });
  $("exportData").onclick = async () => {
    try {
      const res = await fetch("/api/account/export", { credentials: "same-origin" });
      if (!res.ok) throw new Error("Couldn't download your data. Try again.");
      const blob = await res.blob(), a = document.createElement("a");
      a.href = URL.createObjectURL(blob); a.download = "honeybun-data.json"; document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 1000);
    } catch (e) { toast(e.message); }
  };
  $("deleteAcct").onclick = () => { $("delPw").value = ""; $("delErr").textContent = ""; $("delDlg").showModal(); };
  $("delCancel").onclick = () => $("delDlg").close();
  $("delGo").onclick = async () => {
    try {
      await api("/api/account/delete", { method: "POST", body: { password: $("delPw").value } });
      $("delDlg").close();
      try { Object.keys(localStorage).filter((k) => k.startsWith("hb-")).forEach((k) => localStorage.removeItem(k)); } catch {}
      ME = null; NEST = null; authMode = "signup"; showAuth(); toast("Your account was deleted. Take care ♡");
    } catch (e) { $("delErr").textContent = e.message; }
  };
  async function runVerify() {
    show("verify");
    history.replaceState(null, "", "/");
    try {
      await api("/api/email/verify", { method: "POST", body: { token: verifyToken } });
      $("verifyTitle").textContent = "Email confirmed ♡"; $("verifyText").textContent = "Thanks! Reminders and password resets will reach you now.";
    } catch (e) { $("verifyTitle").textContent = "Hmm, that didn't work"; $("verifyText").textContent = e.message; }
    verifyToken = null; $("verifyGo").hidden = false;
  }
  $("verifyGo").onclick = async () => {
    try { await afterAuth(); } catch (e) { authMode = "login"; showAuth(); }
  };

  // ---------- monthly recap card ----------
  const ACCENT_HEX = { blueberry: "#6F93DB", blush: "#EE7FA3", lavender: "#9C82DC", honey: "#DDA13F" };
  let recapBlob = null;
  async function drawRecap() {
    const c = $("recapCanvas"), x = c.getContext("2d"), W = 1080, H = 1350, acc = ACCENT_HEX[NEST.accent] || ACCENT_HEX.blueberry;
    try { await document.fonts.ready; } catch {}
    const F = (w, sz) => `${w} ${sz}px Fredoka, Nunito, "PingFang SC", "Microsoft YaHei", system-ui, sans-serif`;
    const rr = (x0, y0, w, h, r, fill) => { x.beginPath(); x.roundRect(x0, y0, w, h, r); x.fillStyle = fill; x.fill(); };
    x.clearRect(0, 0, W, H); x.fillStyle = "#F3F5FA"; x.fillRect(0, 0, W, H);
    x.fillStyle = acc; x.globalAlpha = .12; x.beginPath(); x.arc(W - 80, 90, 260, 0, 7); x.fill(); x.beginPath(); x.arc(60, H - 40, 200, 0, 7); x.fill(); x.globalAlpha = 1;
    const img = new Image(); img.src = "/icon-512.png";
    await new Promise((r) => { img.onload = r; img.onerror = r; });
    x.save(); x.beginPath(); x.roundRect(80, 80, 150, 150, 42); x.clip(); try { x.drawImage(img, 80, 80, 150, 150); } catch {} x.restore();
    x.fillStyle = "#8E8898"; x.font = F(600, 34); x.fillText("Honeybun", 260, 140);
    x.fillStyle = "#2B2733"; x.font = F(600, 58); x.fillText(monthName(MONTH), 260, 205);
    const inc = ENTRIES.filter((e) => e.type === "income").reduce((s, e) => s + e.amount, 0);
    const out = ENTRIES.filter((e) => e.type === "expense").reduce((s, e) => s + e.amount, 0);
    const kept = inc > 0 ? Math.round(((inc - out) / inc) * 100) : null;
    rr(80, 280, W - 160, 300, 44, "#FFFFFF");
    x.fillStyle = "#8E8898"; x.font = F(600, 36); x.fillText(tr(kept === null ? "Spent this month" : "You kept"), 130, 350);
    x.fillStyle = kept !== null && kept < 0 ? "#D9668C" : acc; x.font = F(600, 150);
    x.fillText(kept === null ? fmt(out) : kept + "%", 124, 510);
    x.fillStyle = "#8E8898"; x.font = F(600, 32);
    if (kept !== null) x.fillText(`${tr("Earned")} ${fmt(inc)}  ·  ${tr("Spent")} ${fmt(out)}`, 130, 555);
    const by = spentByCat(), top = Object.entries(by).sort((a, b) => b[1] - a[1])[0];
    const m = meMember() || {}, li = levelInfo(m.xp || 0), budgets = Object.keys(BUDGETS), under = budgets.filter((k) => (by[k] || 0) <= BUDGETS[k]).length;
    const tiles = [
      ["🐾", tr("Hop streak"), `${streakOf(m)} · ${tr("best")} ${m.best_streak || 0}`],
      ["🥕", tr("Level"), `${li.l} · ${tr(li.title)}`],
      [top ? catOf(top[0]).e : "✨", tr("Top spend"), top ? `${tr(catOf(top[0]).n)} ${fmt(top[1])}` : "–"],
      ["🎯", tr("Budgets kept"), budgets.length ? `${under} / ${budgets.length}` : "–"],
    ];
    tiles.forEach(([e, k, v], i) => {
      const col = i % 2, row = Math.floor(i / 2), tx = 80 + col * 470, ty = 620 + row * 230;
      rr(tx, ty, 450, 200, 38, "#FFFFFF");
      x.font = F(400, 56); x.fillStyle = "#2B2733"; x.fillText(e, tx + 34, ty + 82);
      x.font = F(600, 30); x.fillStyle = "#8E8898";
      let kk = k; while (x.measureText(kk).width > 390 && kk.length > 3) kk = kk.slice(0, -2) + "…";
      x.fillText(kk, tx + 34, ty + 132);
      x.font = F(600, 36); x.fillStyle = "#2B2733";
      let t = v; while (x.measureText(t).width > 390 && t.length > 3) t = t.slice(0, -2) + "…";
      x.fillText(t, tx + 34, ty + 178);
    });
    x.textAlign = "center"; x.font = F(600, 40); x.fillStyle = "#2B2733";
    const msg = tr(kept !== null && kept >= 20 ? "Look at you go! Your bunny is so proud ♡" : streakOf(m) >= 3 ? "Keep hopping. Your bunny is proud of you." : "Every little log helps your bunny grow ♡");
    x.fillText(msg.length > 46 ? msg.slice(0, 45) + "…" : msg, W / 2, 1150);
    x.font = F(600, 34); x.fillStyle = "#8E8898";
    x.fillText(tr("A cute little budget") + " · honeybun.me", W / 2, H - 70); x.textAlign = "left";
    recapBlob = await new Promise((r) => c.toBlob(r, "image/png"));
  }
  $("makeRecap").onclick = async () => { $("rcTitle").textContent = `${monthName(MONTH)}`; $("recapDlg").showModal(); await drawRecap(); };
  $("rcClose").onclick = () => $("recapDlg").close();
  $("rcShare").onclick = async () => {
    if (!recapBlob) return;
    const file = new File([recapBlob], `honeybun-${MONTH}.png`, { type: "image/png" });
    if (navigator.canShare && navigator.canShare({ files: [file] })) { try { await navigator.share({ files: [file], title: "Honeybun" }); } catch {} return; }
    const a = document.createElement("a"); a.href = URL.createObjectURL(recapBlob); a.download = file.name; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  };

  // sticky header gets a hairline once you scroll
  window.addEventListener("scroll", () => $("topBar").classList.toggle("scrolled", window.scrollY > 4), { passive: true });
  drawLangPickers();

  // ---------- "new version deployed" notice ----------
  let APP_VERSION = null, updateShown = false;
  async function fetchVersion() {
    try {
      const heads = await Promise.all(["/app.js", "/"].map((u) => fetch(u, { method: "HEAD", cache: "no-store" })));
      const tags = heads.map((r) => r.headers.get("etag") || r.headers.get("last-modified") || "");
      if (tags.every(Boolean)) return tags.join("|");
      // no version headers: fall back to a quick fingerprint of the code
      const txt = await (await fetch("/app.js", { cache: "no-store" })).text();
      let h = 0; for (let i = 0; i < txt.length; i += 7) h = (h * 31 + txt.charCodeAt(i)) | 0;
      return "h" + txt.length + ":" + h;
    } catch { return null; }
  }
  async function checkForUpdate() {
    if (document.hidden || OFFLINE || updateShown) return;
    const v = await fetchVersion();
    if (!v) return;
    if (!APP_VERSION) { APP_VERSION = v; return; }
    if (v !== APP_VERSION) {
      // nothing important on screen? just refresh. Otherwise ask nicely.
      if (["loading", "auth", "verify"].includes(screen) && !document.querySelector("dialog[open]")) { location.reload(); return; }
      updateShown = true;
      $("updateCard").hidden = false;
    }
  }
  $("updateNow").onclick = () => location.reload();
  $("updateLater").onclick = () => { $("updateCard").hidden = true; setTimeout(() => { updateShown = false; }, 15 * 60 * 1000); };
  setTimeout(checkForUpdate, 1500);
  setInterval(checkForUpdate, 30 * 1000); // every 30 seconds
  document.addEventListener("visibilitychange", () => { if (!document.hidden) checkForUpdate(); });
  window.addEventListener("focus", checkForUpdate);

  // the app started fine, so cancel the stuck-loading fallback
  window.__hbStarted = true;
  try { sessionStorage.removeItem("hb-boot"); } catch {}

  // ---------- start ----------
  (async () => {
    if (resetToken) { show("reset"); return; }
    if (verifyToken) { runVerify(); return; }
    try { await afterAuth(); }
    catch (e) {
      if (e.status === 401) { authMode = pendingCode ? "signup" : store.get("hb-had-account") ? "login" : "signup"; showAuth(); }
      else { showAuth(); $("authErr").textContent = e.message; }
    }
  })();
})();
