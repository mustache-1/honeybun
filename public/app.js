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
  // line icons (replace emoji in the UI)
  const ICONS = {
    house: '<path d="M3 11l9-7 9 7v9H3z"/><path d="M10 20v-5h4v5"/>',
    cart: '<path d="M3 4h2l2.4 11h11L21 8H7"/><circle cx="9" cy="19" r="1.4"/><circle cx="17" cy="19" r="1.4"/>',
    cup: '<path d="M4 10h13v3a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM17 11h1.5a2.5 2.5 0 0 1 0 5H16"/><path d="M8 6c0-1 1-1 1-2M12 6c0-1 1-1 1-2"/>',
    heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
    bolt: '<path d="M13 3L5 14h6l-1 7 8-11h-6z"/>',
    tv: '<rect x="3" y="5" width="18" height="12" rx="3"/><path d="M9 21h6M12 17v4"/>',
    car: '<path d="M5 16l1.5-6h11L19 16M4 16h16v3H4zM7 19v2M17 19v2"/>',
    gift: '<rect x="4" y="9" width="16" height="11" rx="2"/><path d="M12 9v11M4 13h16M12 9c-2-4-6-3-5 0M12 9c2-4 6-3 5 0"/>',
    paw: '<ellipse cx="12" cy="16" rx="4.5" ry="3.8"/><circle cx="6.5" cy="10.5" r="1.8"/><circle cx="10" cy="7" r="1.8"/><circle cx="14" cy="7" r="1.8"/><circle cx="17.5" cy="10.5" r="1.8"/>',
    card: '<rect x="3" y="6" width="18" height="13" rx="3"/><path d="M3 10h18M7 15h4"/>',
    sparkle: '<path d="M12 4v4M12 16v4M4 12h4M16 12h4M7 7l2 2M15 15l2 2M17 7l-2 2M9 15l-2 2"/>',
    coin: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5v9M14.5 9.6c0-1-1.1-1.7-2.5-1.7s-2.5.7-2.5 1.8 1 1.5 2.5 1.8 2.5.9 2.5 2-1.1 1.8-2.5 1.8-2.5-.8-2.5-1.8"/>',
    carrot: '<path d="M6 20l10-11 3 3z"/><path d="M16 9l1-4M17 10l4-2M18 11h4"/>',
    star: '<path d="M12 4l2.3 4.8 5.2.7-3.8 3.6.9 5.2L12 15.9 7.4 18.3l.9-5.2-3.8-3.6 5.2-.7z"/>',
    medal: '<circle cx="12" cy="14" r="5.5"/><path d="M8.5 9.5L6 3h4l2 4 2-4h4l-2.5 6.5"/>',
    basket: '<path d="M3 10h18l-2 9H5z"/><path d="M8 10l3-6M16 10l-3-6M9 14v2M15 14v2"/>',
    cal: '<rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/>',
    target: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r=".8"/>',
    jar: '<path d="M8 8h8l1 2v9a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2v-9z"/><rect x="8" y="4" width="8" height="4" rx="1.5"/>',
    party: '<path d="M4 20l4-11 7 7z"/><path d="M13 4v3M17 7l2-2M18 11h3"/>',
    home2: '<path d="M4 20V10l8-6 8 6v10z"/><path d="M9 20v-5h6v5"/>',
    moon: '<path d="M19 14.5A7.5 7.5 0 1 1 9.5 5a6 6 0 0 0 9.5 9.5z"/>',
    crown: '<path d="M4 18l2-10 6 4 6-4 2 10z"/>',
    calcheck: '<rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 14l2 2 4-4"/>',
    lock: '<rect x="6" y="11" width="12" height="9" rx="2.5"/><path d="M8.5 11V8.5a3.5 3.5 0 0 1 7 0V11"/>',
    chev: '<path d="M9 6l6 6-6 6"/>',
  };
  const icon = (k, w = 1.8) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[k] || ICONS.sparkle}</svg>`;
  const CAT_LOOK = { home: ["house", "blue"], groc: ["cart", "green"], food: ["cup", "honey"], date: ["heart", "rose"], bills: ["bolt", "lilac"], subs: ["tv", "lilac"],
    car: ["car", "blue"], fun: ["gift", "rose"], pets: ["paw", "honey"], debt: ["card", "rose"], other: ["sparkle", "gray"] };
  const tileHtml = (k, tint, size = 38) => `<span class="ct t-${tint}" style="width:${size}px;height:${size}px;border-radius:${Math.round(size * 0.34)}px">${icon(k)}</span>`;
  const catTile = (id, size) => { const [k, t] = CAT_LOOK[id] || CAT_LOOK.other; return tileHtml(k, t, size); };
  const incTile = (size) => tileHtml("coin", "green", size);
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

  const DEVICE = (() => {
    let d = store.get("hb-device");
    if (!d || !/^[A-Za-z0-9_-]{16,64}$/.test(d)) {
      const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
      d = Array.from(crypto.getRandomValues(new Uint8Array(22)), (b) => abc[b % 64]).join(""); store.set("hb-device", d);
    }
    return d;
  })();
  async function api(path, { method = "GET", body } = {}) {
    const opts = { method, credentials: "same-origin", headers: {} };
    opts.headers["x-local-date"] = today();
    opts.headers["x-hb-device"] = DEVICE;
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
  let GOALS = [], BUDGETS = {}, DEBTS = [], DEBTPAYS = [], SETUP_DONE = true, INBOX = { unread: 0, latest: null }, REPEATS = [], CARRY = {}, PASSKEYS = [];
  let MONTH = today().slice(0, 7), YEAR = new Date().getFullYear(), YDATA = null;
  let billsTab = "bills"; // Plan: "bills" or "subs"
  let duePage = 0, dueSize = 5, lastDueLeft = 0; // Home: Coming up pages
  let billsPage = 0, billsSize = 6, billsSig = ""; // Plan: bills / subscriptions pages
  let debtPage = 0, debtSize = 3, debtSig = ""; // Plan: debts pages (desktop)
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
    // referral links: /r/CODE or ?ref=CODE (remembered for 60 days until signup)
    const rf = location.pathname.match(/^\/r\/([A-Za-z0-9]{4,16})\/?$/), rq = new URLSearchParams(location.search).get("ref");
    const rc = rf ? rf[1] : rq && /^[A-Za-z0-9]{4,16}$/.test(rq) ? rq : null;
    if (rc) { store.set("hb-ref", JSON.stringify({ c: rc.toUpperCase(), t: Date.now() })); history.replaceState(null, "", "/" + location.hash); }
  }
  // "Buy me a coffee" support link: paste the page address here and the buttons appear
  const COFFEE_URL = "https://buymeacoffee.com/honeybunapp";
  if (COFFEE_URL) document.querySelectorAll("[data-coffee]").forEach((a) => { a.href = COFFEE_URL; a.closest("[data-coffee-wrap]").hidden = false; });
  // the Windows app opens honeybun.me/?app=desktop: it skips the marketing page and goes straight to log in / sign up
  const IS_DESKTOP_APP = (() => {
    if (new URLSearchParams(location.search).get("app") === "desktop") { store.set("hb-desktop", "1"); history.replaceState(null, "", location.pathname + location.hash); }
    return store.get("hb-desktop") === "1";
  })();
  // The iPhone app (a native shell around this site) adds a Face ID lock through its BiometricLock plugin.
  const IOS_NATIVE = !!(window.Capacitor && window.Capacitor.getPlatform && window.Capacitor.getPlatform() === "ios");
  const BIO = IOS_NATIVE && window.Capacitor.Plugins && window.Capacitor.Plugins.BiometricLock;
  const NATIVE_PLUGINS = IOS_NATIVE ? window.Capacitor.Plugins || {} : {};
  const HBN = NATIVE_PLUGINS.HoneybunNative, PUSHP = NATIVE_PLUGINS.PushNotifications;
  let nativeDone = false;
  // give the widget and Siri this phone's own token, and keep push notifications registered
  async function nativeSetup() {
    if (!ME || !(HBN || PUSHP)) return;
    if (HBN) {
      let tok = store.get("hb-app-token");
      if (!tok) { try { tok = (await api("/api/app/token", { method: "POST" })).token; store.set("hb-app-token", tok); } catch { tok = null; } }
      if (tok) { try { await HBN.setToken({ token: tok }); } catch {} }
    }
    if (PUSHP && store.get("hb-apns") === "1") registerPush(true);
  }
  let pushListening = false;
  async function registerPush(quiet) {
    if (!PUSHP) return false;
    if (!pushListening) {
      pushListening = true;
      PUSHP.addListener("registration", async (t) => { try { await api("/api/push/apns", { method: "POST", body: { token: t.value } }); store.set("hb-apns-token", t.value); } catch {} });
      PUSHP.addListener("registrationError", () => {});
    }
    try {
      let perm = await PUSHP.checkPermissions();
      if (perm.receive === "prompt" && !quiet) perm = await PUSHP.requestPermissions();
      if (perm.receive !== "granted") return false;
      await PUSHP.register();
      return true;
    } catch { return false; }
  }
  let lockHiddenAt = 0, unlocking = false, lockChecked = false;
  const lockOn = () => store.get("hb-lock") === "1";
  async function tryUnlock() {
    if (!BIO || unlocking) return;
    unlocking = true;
    try {
      const r = await BIO.authenticate({ reason: tr("Unlock Honeybun") });
      if (r && r.success) $("lockOverlay").hidden = true; else $("lockMsg").textContent = tr("Couldn't unlock. Try again.");
    } catch { $("lockMsg").textContent = tr("Couldn't unlock. Try again."); }
    unlocking = false;
  }
  function lockNow() { if (!BIO || !lockOn() || !ME) return; $("lockOverlay").hidden = false; $("lockMsg").textContent = tr("Use Face ID to open your budget."); tryUnlock(); }
  if (PUSHP) {
    const row = $("pushRow");
    row.hidden = false;
    const draw = () => { const on = store.get("hb-apns") === "1"; $("pushState").textContent = tr(on ? "On" : "Off"); $("pushState").classList.toggle("on", on); };
    draw();
    row.onclick = async () => {
      if (store.get("hb-apns") === "1") {
        const t = store.get("hb-apns-token");
        store.set("hb-apns", "0");
        if (t) { try { await api("/api/push/apns", { method: "DELETE", body: { token: t } }); } catch {} }
        draw(); return;
      }
      if (await registerPush(false)) { store.set("hb-apns", "1"); draw(); toast(tr("Notifications are on")); }
      else toast(tr("Allow notifications for Honeybun in your iPhone Settings."));
    };
  }
  if (IOS_NATIVE) {
    const row = $("siriRow");
    row.hidden = false;
    row.onclick = () => toast(tr('Try: "Hey Siri, how much is left in Honeybun?"'));
  }
  if (BIO) {
    $("lockTry").onclick = tryUnlock;
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) lockHiddenAt = Date.now();
      else if (lockOn() && lockHiddenAt && Date.now() - lockHiddenAt > 15000) lockNow();
    });
    const row = $("lockRow");
    row.hidden = false;
    const draw = () => { const on = lockOn(); $("lockState").textContent = tr(on ? "On" : "Off"); $("lockState").classList.toggle("on", on); };
    draw();
    row.onclick = async () => {
      if (lockOn()) { store.set("hb-lock", "0"); draw(); return; }
      try {
        const a = await BIO.available();
        if (!a.available) { toast(tr("Set up Face ID or a passcode in your iPhone Settings first.")); return; }
        const r = await BIO.authenticate({ reason: tr("Turn on the Honeybun lock") });
        if (r && r.success) { store.set("hb-lock", "1"); draw(); toast(tr("Lock is on")); }
      } catch { toast(tr("Couldn't turn the lock on")); }
    };
  }
  function pendingRef() { try { const r = JSON.parse(store.get("hb-ref") || "null"); return r && Date.now() - r.t < 60 * 86400000 ? r.c : null; } catch { return null; } }
  const member = (id) => MEMBERS.find((m) => m.id === id) || { name: "Someone", emoji: "❔", color: "#EEE" };
  const meMember = () => MEMBERS.find((m) => m.id === ME?.id);
  const others = (id) => MEMBERS.filter((m) => m.id !== id);
  const KIND = () => NEST?.kind || "couple";
  // Joint account: the household keeps its money in one pot, so everything adds up and nobody owes anybody
  const JOINT = () => !!NEST?.joint && MEMBERS.length > 1 && KIND() === "couple";
  const yesterday = () => toS(addDays(parseD(today()), -1));
  const streakOf = (m) => (m && (m.last_day === today() || m.last_day === yesterday()) ? m.streak : 0);
  const loggedToday = () => meMember()?.last_day === today();

  // ---------- screens ----------
  const APP_SCREENS = ["home", "plan", "add", "stats", "share", "us", "inbox", "settings", "help", "refer", "updates"];
  const ALL_SCREENS = ["loading", "landing", "auth", "reset", "verify", "setup", "onboard", ...APP_SCREENS];
  function show(s) {
    screen = s;
    fitDesktop();
    ALL_SCREENS.forEach((k) => ($("scr-" + k).hidden = k !== s));
    const inApp = APP_SCREENS.includes(s);
    if (inApp && !lockChecked) { lockChecked = true; lockNow(); }
    if (inApp && !nativeDone) { nativeDone = true; nativeSetup(); }
    $("nav").hidden = !inApp; $("topBar").hidden = !inApp;
    { const mn = $("monthNav"), slot = document.querySelector(`#scr-${s} .ph-slot`);
      if (slot) { slot.appendChild(mn); mn.style.display = ""; } else mn.style.display = "none"; }
    document.querySelectorAll("nav.bottom [data-go]").forEach((b) => b.dataset.go === (s === "share" && !matchMedia("(min-width: 900px)").matches ? "us" : s) ? b.setAttribute("aria-current", "page") : b.removeAttribute("aria-current"));
    window.scrollTo(0, 0);
    if (s === "stats") loadYear();
    if (s === "refer" && ME) loadRef();
    if (s === "updates") openUpdates();
    if (inApp) render();
  }
  document.querySelectorAll("nav.bottom [data-go]").forEach((b) => (b.onclick = () => {
    if (b.dataset.go === "add") openAdd(); else { if (screen === "add") editing = null; show(b.dataset.go); }
  }));

  // ---------- auth ----------
  function showAuth() {
    $("inviteNotice").hidden = !pendingCode;
    $("refNotice").hidden = !!pendingCode || !pendingRef();
    $("authBackWrap").hidden = !!pendingCode;
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
    $("passkeyWrap").hidden = $("passkeyLogin").hidden = !(m === "login" && hasPasskeys());
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
      await api(authMode === "signup" ? "/api/signup" : "/api/login", { method: "POST", body: { name, email, password, lang: LANG, ...(authMode === "signup" && pendingRef() ? { ref: pendingRef() } : {}) } });
      if (authMode === "signup") store.set("hb-ref", "");
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
    if (HBN || PUSHP) {
      const t = store.get("hb-apns-token");
      try { if (t) await api("/api/push/apns", { method: "DELETE", body: { token: t } }); } catch {}
      try { await api("/api/app/token", { method: "DELETE" }); } catch {}
      try { if (HBN) await HBN.clear(); } catch {}
      store.set("hb-app-token", ""); store.set("hb-apns", "0");
    }
    try { await api("/api/logout", { method: "POST" }); } catch {}
    try { const inv = window.__TAURI_INTERNALS__ && window.__TAURI_INTERNALS__.invoke; if (inv) inv("set_unread", { count: 0 }).catch(() => {}); } catch {}
    ME = null; NEST = null; MEMBERS = []; ENTRIES = []; filter = null; editing = null;
    authMode = "login"; showAuth();
  }
  $("setupLogout").onclick = logout;
  document.querySelectorAll("[data-auth-go]").forEach((b) => (b.onclick = () => { authMode = b.dataset.authGo; showAuth(); }));
  $("authBack").onclick = () => show("landing");
  document.querySelectorAll('#scr-landing a[href^="#lp-"]').forEach((a) => (a.onclick = (ev) => { ev.preventDefault(); document.querySelector(a.getAttribute("href"))?.scrollIntoView({ behavior: "smooth" }); }));
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
    // the budget refresh only sends id, name and email: merge them in so email-confirmed, reminders, referrals, etc. aren't wiped
    const wasJoint = NEST ? !!NEST.joint : null;
    ME = { ...(ME || {}), ...d.me }; NEST = d.nest; MEMBERS = d.members;
    // your partner switched Joint account on or off: everything on this screen follows, and we say so
    if (wasJoint !== null && wasJoint !== !!NEST.joint) toast(tr(NEST.joint ? "Joint account was turned on. Everything adds up together." : "Joint account was turned off."));
    ENTRIES = d.entries.map((e) => ({ ...e, amount: e.amount_cents / 100, shared: !!e.shared, private: !!e.private }));
    queued().filter((q) => (q.date || "").slice(0, 7) === MONTH).forEach((q) => ENTRIES.unshift({
      id: q.pending_id, pending: true, member_id: q.member_id, type: q.type, amount: +q.amount, amount_cents: Math.round(q.amount * 100),
      label: q.label, category: q.category, shared: !!q.shared, split_mode: q.split_mode, split_value: q.split_value, private: !!q.private, date: q.date }));
    BAL = d.balances; SETTLES = d.settlements; RECUR = d.recurring; JAR = d.jar;
    document.documentElement.setAttribute("data-accent", d.nest.accent || "blush");
    GOALS = d.goals; DEBTS = d.debts; DEBTPAYS = d.debt_payments; SETUP_DONE = d.setup_done;
    BUDGETS = Object.fromEntries(d.budgets.map((b) => [b.category, b.limit_cents / 100]));
    REPEATS = d.repeats || []; CARRY = d.carry || {};
    LOGGED = new Set(d.logged.map((l) => l.recurring_id + "|" + l.occ_date));
    if (d.inbox) {
      const prev = INBOX.unread; let latest = null;
      if (d.inbox.latest) { const [id, kind, ...rest] = d.inbox.latest.split("|"); try { latest = { id, kind, data: JSON.parse(rest.join("|")) }; } catch {} }
      INBOX = { unread: d.inbox.unread || 0, latest };
      if (INBOX.unread > prev && prev >= 0 && document.getElementById("inboxBtn")) { const b = $("inboxBtn"); b.classList.remove("wiggle"); void b.offsetWidth; b.classList.add("wiggle"); }
    }
    if (!MEMBERS.some((m) => m.id === who)) who = ME.id;
    if (filter && !MEMBERS.some((m) => m.id === filter)) filter = null;
    if (APP_SCREENS.includes(screen)) render();
  }
  async function refresh() {
    if (!ME || !APP_SCREENS.includes(screen) || document.hidden || window.hbNativeHidden || screen === "add") return;
    if (document.querySelector("dialog[open]")) return;
    try { await loadNest(); } catch {}
    // pick up account changes made elsewhere (e.g. the email was confirmed in another tab), at most once a minute
    if (Date.now() - (refresh.meAt || 0) > 60000) {
      refresh.meAt = Date.now();
      try { const m = await api("/api/me"); if (m && m.user) { ME = { ...ME, ...m.user }; render(); } } catch {}
    }
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
    return `<g fill="var(--bun-body, #f8f4f8)" stroke="#141217" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">
      <path d="M44 52 C34 30 34 8 42 6 C50 4 54 28 54 46"/><path d="M76 52 C86 30 86 8 78 6 C70 4 66 28 66 46"/>
      <ellipse cx="60" cy="82" rx="38" ry="34"/>
      <circle cx="47" cy="78" r="3.5" fill="#141217" stroke="none"/><circle cx="73" cy="78" r="3.5" fill="#141217" stroke="none"/>
      <ellipse cx="38" cy="90" rx="6" ry="3.5" fill="#F6B7CB" stroke="none"/><ellipse cx="82" cy="90" rx="6" ry="3.5" fill="#F6B7CB" stroke="none"/>
      <path d="M52 89 q8 8 16 0" fill="none" stroke-width="3"/>${gearSvg(l)}</g>`;
  }
  function rewardToast(rw, msg, undo) {
    if (!rw) { toast(msg, undo ? tr("Undo") : undefined, undo); return; }
    toast(rw.gained > 0 ? `${msg}  +${rw.gained} 🥕` : msg, undo ? tr("Undo") : undefined, undo);
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
    $("streakTile").innerHTML = `${tileHtml("paw", "honey", 40)}<span class="tt"><b>${st === 1 ? "1 day" : st + " days"}</b>
      <small class="${done ? "" : "todo"}">${done ? "hop streak" : "Log today to hop"}</small></span>`;
    $("levelTile").innerHTML = `${tileHtml("carrot", "rose", 40)}<span class="tt"><b>Level ${li.l}</b><small>${m.xp || 0} carrots</small>
      <span class="xp"><i style="width:${li.pct * 100}%"></i></span></span>`;
    $("gear").innerHTML = gearSvg(li.l);
  }
  $("streakTile").onclick = () => show("stats");
  $("levelTile").onclick = () => show("stats");


  const BADGES = [
    { k: "star", e: "🐣", n: "First hop", d: "Log your first thing", ok: (m) => m.logs >= 1 },
    { k: "paw", e: "🐾", n: "3-day hop", d: "Keep a 3-day streak", ok: (m) => m.best_streak >= 3 },
    { k: "sparkle", e: "🌟", n: "Week hopper", d: "Keep a 7-day streak", ok: (m) => m.best_streak >= 7 },
    { k: "medal", e: "🏅", n: "Month marathon", d: "Keep a 30-day streak", ok: (m) => m.best_streak >= 30 },
    { k: "carrot", e: "🥕", n: "Carrot counter", d: "Log 50 things", ok: (m) => m.logs >= 50 },
    { k: "basket", e: "🧺", n: "Carrot basket", d: "Log 200 things", ok: (m) => m.logs >= 200 },
    { k: "coin", e: "💰", n: "Payday planner", d: "Add a payday", ok: () => RECUR.some((r) => r.type === "income") },
    { k: "calcheck", e: "📅", n: "Bill boss", d: "Add 3 bills", ok: () => RECUR.filter((r) => r.type === "expense").length >= 3 },
    { k: "target", e: "🎯", n: "Limit setter", d: "Set a monthly budget", ok: () => Object.keys(BUDGETS).length > 0 },
    { k: "jar", e: "🍯", n: "Goal getter", d: "Reach a savings goal", ok: () => GOALS.some((g) => g.saved_cents >= g.target_cents) },
    { k: "party", e: "🎉", n: "Debt free-ish", d: "Pay off a debt", ok: () => DEBTS.some((d) => d.paid_cents >= d.start_cents) },
    { k: "heart", e: "💞", n: "Better together", d: "Share your budget", ok: () => MEMBERS.length >= 2 },
    { k: "home2", e: "🏡", n: "Burrow builder", d: "Reach level 5", ok: (m) => levelFor(m.xp) >= 5 },
    { k: "moon", e: "🌙", n: "Moon hopper", d: "Reach level 9", ok: (m) => levelFor(m.xp) >= 9 },
    { k: "crown", e: "👑", n: "Legend", d: "Reach level 10", ok: (m) => levelFor(m.xp) >= 10 },
    { k: "cal", e: "🗓️", n: "Year in review", d: "Log something in 6 different months", ok: () => YDATA && new Set(YDATA.entries.map((e) => e.date.slice(0, 7))).size >= 6 },
  ];
  function renderBurrow() {
    const m = meMember(); if (!m) return;
    const li = levelInfo(m.xp || 0), st = streakOf(m);
    const wk = (() => { const d = parseD(today()); return toS(addDays(d, -((d.getDay() + 6) % 7))); })();
    const carrots = MEMBERS.length > 1 ? " · " + MEMBERS.map((x) => `${x.name} ${x.week_key === wk ? x.week_xp : 0} 🥕`).join(" · ") : ` · ${m.xp || 0} ${tr("carrots")}`;
    let got = 0;
    const bg = $("badges"); bg.innerHTML = "";
    BADGES.forEach((b) => {
      const on = !!b.ok(m); if (on) got++;
      const el = document.createElement("button"); el.className = "badge" + (on ? " on" : "");
      el.innerHTML = `<i>${on ? icon(b.k) : icon("lock")}</i>${esc(b.n)}<small>${esc(on ? "earned" : b.d)}</small>`;
      el.onclick = () => toast(on ? `${b.n}: unlocked ♡` : `${b.n}: ${b.d}`);
      bg.appendChild(el);
    });
    $("badgeCount").textContent = `${got} of ${BADGES.length}`;
    $("burrow").innerHTML = `<span class="bc"><svg viewBox="0 0 120 128" aria-hidden="true">${bunnySvg(li.l)}</svg></span>
      <span class="tx"><b>${esc(tr("Level"))} ${li.l} · ${esc(li.title)}</b><span class="xpbar"><i style="width:${li.pct * 100}%"></i></span>
      <small>🐾 ${st}-day streak${esc(carrots)}</small></span>
      <button type="button" class="bdg" id="openBadges" aria-label="${got} of ${BADGES.length} badges">🏅 ${got}/${BADGES.length} ›</button>`;
    $("openBadges").onclick = () => $("badgeDlg").showModal();
  }
  $("badgeClose").onclick = () => $("badgeDlg").close();

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
    li.innerHTML = `${isIn ? incTile(32) : catTile(r.category, 32)}<span class="t">${esc(r.label)} · ${fmt(r.amount_cents / 100)}<small>${FREQ_NAME[r.freq]}${n ? ", next " + shortDay(n) : ""}${isIn ? ", " + esc(member(r.member_id).name) : r.shared ? ", split" : ""}</small></span><button aria-label="Remove">✕</button>`;
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
        const el = document.createElement("button"); el.type = "button"; el.textContent = q.n;
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
    li.innerHTML = `<div class="ic">${isIn ? incTile(38) : catTile(c.id, 38)}</div>
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
    if (JOINT()) return [];
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
    lastDueLeft = left;
    box.innerHTML = `<div class="due-h"><h2>${payday ? "Before payday" : "Coming up"}</h2><span>${payday ? dayName(payday) : "next 30 days"}</span></div>`;
    if (!bills.length) box.insertAdjacentHTML("beforeend", `<p class="due-empty">Nothing due${payday ? " before payday" : " soon"} ♡</p>`);
    // bills first, then paydays; shown a page at a time so a long list never pushes the screen into scrolling
    const items = bills.map((b) => ({ b })).concat(pays.map((p) => ({ p })));
    const pages = Math.max(1, Math.ceil(items.length / dueSize));
    duePage = Math.min(duePage, pages - 1);
    items.slice(duePage * dueSize, (duePage + 1) * dueSize).forEach(({ b, p }) => {
      const row = document.createElement("div"); row.className = "due-row";
      if (b) {
        const c = CATS.find((x) => x.id === b.r.category) || CATS[4];
        row.innerHTML = `<div class="ic">${catTile(c.id, 38)}</div><div class="mid"><div class="t">${esc(b.r.label)}</div>
          <div class="s ${b.late ? "late" : ""}">${b.late ? "Overdue, was due " : "Due "}${shortDay(b.d)}</div></div>
          <div class="amt">${fmt(b.r.amount_cents / 100)}</div><button class="mini">Paid</button>`;
        row.querySelector("button").onclick = (ev) => logOcc(b.r, b.d, ev.currentTarget);
      } else {
        const m = member(p.r.member_id);
        row.innerHTML = `<div class="ic">${incTile(38)}</div><div class="mid"><div class="t">${esc(p.r.label)}</div>
          <div class="s">${esc(m.name)} gets paid ${shortDay(p.d)}</div></div>
          <div class="amt" style="color:var(--mint-d)">+${fmt(p.r.amount_cents / 100)}</div><button class="mini inc">Got it</button>`;
        row.querySelector("button").onclick = (ev) => logOcc(p.r, p.d, ev.currentTarget);
      }
      box.appendChild(row);
    });
    if (pages > 1) {
      const pg = document.createElement("div"); pg.className = "due-pg";
      pg.innerHTML = `<button type="button" aria-label="${esc(tr("Previous page"))}" ${duePage === 0 ? "disabled" : ""}>‹</button><span>${duePage + 1} / ${pages}</span><button type="button" aria-label="${esc(tr("Next page"))}" ${duePage >= pages - 1 ? "disabled" : ""}>›</button>`;
      const [prev, next] = pg.querySelectorAll("button");
      prev.onclick = () => { duePage--; renderDue(left); fitDesktop(); };
      next.onclick = () => { duePage++; renderDue(left); fitDesktop(); };
      box.appendChild(pg);
    }
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
    document.documentElement.setAttribute("data-accent", NEST.accent || "blush");
    $("monthLbl").textContent = monthName(MONTH, true);
    const names = MEMBERS.map((m) => m.name);
    $("hi").textContent = NEST.name || (MEMBERS.length === 2 ? `${names[0]} & ${names[1]}` : MEMBERS.length === 1 ? names[0] : "Our family");
    const hr = new Date().getHours();
    $("greet").textContent = hr < 12 ? "Good morning" : hr < 18 ? "Good afternoon" : "Good evening";
    $("hdrAvs").innerHTML = MEMBERS.slice(0, 3).map((m) => `<span class="av" style="background:${esc(m.color)}">${esc(m.emoji)}</span>`).join("");
    { const couple = KIND() === "couple"; $("navShare").hidden = !couple; $("usShareBtn").hidden = !couple || MEMBERS.length < 2; $("shBack").onclick = () => show("us"); $("usShareBtn").onclick = () => show("share"); 
      if (!couple && screen === "share") { show("home"); return; } }
    $("usLabel").textContent = KIND() === "solo" && MEMBERS.length < 2 ? "Me" : "Together";
    $("inboxBadge").hidden = !INBOX.unread; $("inboxBadge").textContent = INBOX.unread > 9 ? "9+" : INBOX.unread;
    $("sideBadge").hidden = !INBOX.unread; $("sideBadge").textContent = INBOX.unread > 9 ? "9+" : INBOX.unread;
    $("sideAvs").innerHTML = $("hdrAvs").innerHTML; $("sideName").textContent = $("hi").textContent;
    { const m = meMember() || {}; $("sideSub").textContent = tr({ solo: "Just me", couple: "Couple", family: "Family" }[KIND()]) + " · Lv " + levelInfo(m.xp || 0).l; }

    if (JOINT() && filter) filter = null;
    const all = ENTRIES, view = filter ? all.filter((e) => e.member_id === filter) : all;
    const sum = (arr, t) => arr.filter((e) => e.type === t).reduce((s, e) => s + e.amount, 0);
    const inc = sum(view, "income"), out = sum(view, "expense"), left = inc - out;

    if (screen === "home") {
      const lbl = { solo: "Left for me this month", couple: "Left for us this month", family: "Left for our family this month" }[KIND()];
      $("leftLbl").textContent = filter ? member(filter).name + "'s balance in" : "Left in";
      $("heroMonth").textContent = new Date(+MONTH.slice(0, 4), +MONTH.slice(5) - 1, 1).toLocaleDateString(LOCALE, { month: "long" });
      { const [whole, cents] = fmt(left).split("."); $("leftAmt").innerHTML = `${esc(whole)}${cents ? `<span class="cents">.${esc(cents)}</span>` : ""}`; }
      $("leftAmt").classList.toggle("neg", left < 0);
      const chip = $("heroChip"), ratio = inc > 0 ? out / inc : out > 0 ? 2 : 0;
      chip.hidden = !inc && !out;
      chip.className = "chip " + (ratio > 1 ? "over" : ratio > 0.85 ? "warn" : "ok");
      chip.textContent = ratio > 1 ? "Over budget" : ratio > 0.85 ? "Almost there" : "On track";
      $("meter").style.width = inc > 0 ? Math.min(100, (out / inc) * 100) + "%" : out > 0 ? "100%" : "0";
      $("flowIn").textContent = fmt(inc); $("flowOut").textContent = fmt(out);
      $("billsDue").textContent = MONTH === today().slice(0, 7) && RECUR.length ? fmt(upcoming().bills.reduce((a, b) => a + b.r.amount_cents / 100, 0)) : "–";
      $("monthLeft").textContent = inc ? Math.max(0, Math.round(((inc - out) / inc) * 100)) + "%" : "–";
      const hj = $("homeJars");
      hj.innerHTML = GOALS.length ? `<div class="home-jars"><div class="hj-h"><h2>Honey jars</h2><button class="linkbtn" data-go-plan>Plan</button></div>${GOALS.slice(0, 3).map((g) => {
        const saved = g.saved_cents / 100, target = g.target_cents / 100, pct = target ? Math.min(100, (saved / target) * 100) : 0;
        return `<div class="hj"><i><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 8h8l1 2v9a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2v-9z"/><rect x="8" y="4" width="8" height="4" rx="1.5"/></svg></i><span><span class="l"><span>${esc(g.name)}</span><small>${fmt(saved).replace(/\.00$/, "")} of ${fmt(target).replace(/\.00$/, "")}</small></span><span class="trk"><b style="width:${pct}%"></b></span></span></div>`; }).join("")}</div>` : "";
      hj.querySelector("[data-go-plan]")?.addEventListener("click", () => show("plan"));
      setBunny(left, inc, out, view.length > 0);
      $("bunNote").onclick = openInbox;
      const bub = $("bubble");
      if (INBOX.unread && INBOX.latest) {
        const t = msgText(INBOX.latest);
        bub.classList.add("has-msg"); bub.setAttribute("data-nt", "");
        bub.textContent = t;
      } else { bub.classList.remove("has-msg"); bub.removeAttribute("data-nt"); }
      renderPill();
      renderRefCard();
      renderTip(false);
      renderBunExtras();
      $("verifyBanner").hidden = !!ME.verified || +(store.get("hb-verify-hide") || 0) > Date.now();
      const isThisMonth = MONTH === today().slice(0, 7);
      $("dueCard").hidden = !isThisMonth;
      if (isThisMonth) renderDue(sum(all, "income") - sum(all, "expense"));

      // budget heads-up
      const by = spentByCat();
      const warn = Object.entries(BUDGETS).map(([c, lim]) => ({ c, lim, sp: by[c] || 0 })).filter((x) => x.sp >= x.lim * 0.8).sort((a, b) => b.sp / b.lim - a.sp / a.lim).slice(0, 2);
      $("homeBud").innerHTML = [].map((x) => `<div class="home-bud"><span>${esc(catOf(x.c).n)}</span>
        <small>${x.sp > x.lim ? "Over by " + fmt(x.sp - x.lim) : fmt(x.lim - x.sp) + " left"}</small></div>`).join("");
      $("homeBud").onclick = () => show("plan");

      const cp = $("couple"); cp.innerHTML = "";
      const amp = () => { const h = document.createElement("span"); h.className = "heart"; h.textContent = "&"; h.setAttribute("aria-hidden", "true"); return h; };
      if (JOINT()) {
        // one card for the joint account instead of a card per person
        const ji = all.filter((e) => e.type === "income").reduce((a, e) => a + e.amount, 0), jo = all.filter((e) => e.type === "expense").reduce((a, e) => a + e.amount, 0);
        const b = document.createElement("div"); b.className = "pal joint";
        b.setAttribute("aria-label", `Joint account: came in ${fmt(ji)}, spent ${fmt(jo)}.`);
        b.innerHTML = `<span class="faces">${MEMBERS.slice(0, 3).map((m) => `<span class="face" style="background:${esc(m.color)}">${esc(m.emoji)}</span>`).join("")}</span><span class="nm">${esc(tr("Joint account"))}</span><span class="st">${esc(MEMBERS.map((m) => m.name).join(" & "))}<br>+${fmt(ji)} / −${fmt(jo).replace("−", "")}</span>`;
        cp.appendChild(b);
      } else
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
        b.onclick = () => { show("us"); setTimeout(() => $("inviteCard").scrollIntoView({ behavior: "smooth" }), 40); };
        cp.append(amp(), b);
      }
      const fn = $("filterNote");
      if (filter) {
        fn.hidden = false; fn.textContent = `Only ${member(filter).name}'s money. `;
        const c = document.createElement("button"); c.className = "linkbtn"; c.textContent = "Show everyone"; c.onclick = () => { filter = null; render(); }; fn.appendChild(c);
      } else fn.hidden = true;

      const rc = $("recent"); rc.innerHTML = "";
      if (!view.length) rc.innerHTML = `<li class="empty" style="justify-content:center;border:0">Nothing yet for ${esc(monthName(MONTH))}. Tap + to add something.</li>`;
      const latestN = matchMedia("(min-width: 900px)").matches ? 10 : 5; // desktop has room for two columns of five
      view.slice(0, latestN).forEach((e) => rc.appendChild(entryLi(e)));
      $("seeAll").hidden = view.length <= latestN;
    }

    if (screen === "add") renderForm();
    if (screen === "help") { mailLinks(); renderHelp(); }
    if (screen === "plan") renderPlan();
    if (screen === "stats") renderStats();
    if (screen === "share") renderShare();

    if (screen === "us") {
      $("settleWrap").hidden = MEMBERS.length < 2;
      const st = $("settle"), ps = pairs();
      { const h = $("settleWrap").querySelector(".title h2"), sp = $("settleWrap").querySelector(".title span");
        h.textContent = tr(JOINT() ? "Joint account" : "Balance"); sp.textContent = tr(JOINT() ? "one shared pot" : "split expenses"); }
      if (JOINT()) {
        const ji = all.filter((e) => e.type === "income").reduce((a, e) => a + e.amount, 0), jo = all.filter((e) => e.type === "expense").reduce((a, e) => a + e.amount, 0);
        st.innerHTML = `<div class="balance">${fmt(ji - jo)}</div><div class="balance-note">${esc(tr("left in your joint account this month"))}</div>` +
          `<div class="owe"><span>${esc(tr("Came in"))}</span><span class="amt">${fmt(ji)}</span></div><div class="owe"><span>${esc(tr("Spent"))}</span><span class="amt">${fmt(jo)}</span></div>` +
          `<p class="hint" style="margin:8px 0 0">${esc(tr("Everything adds up together, so nobody owes anybody."))}</p>`;
      } else
      if (!ps.length) st.innerHTML = `<div class="balance">$0.00</div><div class="balance-note">You're all even ♡</div>`;
      else {
        const p0 = ps[0];
        st.innerHTML = `<div class="balance">${fmt(p0.amount)}</div><div class="balance-note"></div><button class="settle-btn">Settle up</button>`;
        st.querySelector(".balance-note").textContent = `${p0.from.name} owes ${p0.to.name}`;
        st.querySelector(".settle-btn").onclick = () => openSettle(p0);
        ps.slice(1).forEach((p) => {
          const d = document.createElement("div"); d.className = "owe";
          d.innerHTML = `<span class="f">${esc(p.from.emoji)}</span><span>${esc(p.from.name)} owes ${esc(p.to.name)}</span><span class="amt">${fmt(p.amount)}</span><button class="mini inc">Mark paid</button>`;
          d.querySelector("button").onclick = () => openSettle(p);
          st.appendChild(d);
        });
      }
      const um = $("usMembers"); um.innerHTML = "";
      MEMBERS.forEach((m) => {
        const spent = all.filter((e) => e.member_id === m.id && e.type === "expense").reduce((a, e) => a + e.amount, 0);
        const r = document.createElement("div"); r.className = "member";
        r.innerHTML = `<span class="face" style="background:${esc(m.color)}">${esc(m.emoji)}</span><span class="meta"><b>${esc(m.name)}</b><small>${JOINT() ? `${esc(tr("added"))} ${fmt(all.filter((e) => e.member_id === m.id && e.type === "income").reduce((a, e) => a + e.amount, 0))} · ${esc(tr("spent"))} ${fmt(spent)}` : `${fmt(spent)} spent this month`}</small></span>${m.id === ME.id ? '<span class="tagb">you</span>' : ""}`;
        um.appendChild(r);
      });
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
        if (!all.length) { $("list").innerHTML = `<li class="empty" style="justify-content:center;border:0">Nothing logged for ${esc(monthName(MONTH))}.</li>`; $("listPager").hidden = true; }
        else drawPaged(all, "m:" + MONTH);
      }
      $("inviteTitle").textContent = { solo: "Invite someone (optional)", couple: "Invite your partner", family: "Invite your family" }[KIND()];
      $("inviteCode").textContent = prettyCode(NEST.invite_code);
      $("inviteLink").textContent = inviteUrl();
      $("shareInvite").hidden = !navigator.share;
    }
    if (screen === "refer") renderRefer();
    if (screen === "settings") {
      if (ME.ref) { $("refRowT").textContent = R(`Invite friends, earn ${refAmt(ME.ref)}`, `Invita amigos y gana ${refAmt(ME.ref)}`, `邀请好友，赢 ${refAmt(ME.ref)}`); $("refRowS").textContent = refSub(ME.ref); }
      $("openRefer").hidden = !ME.ref;
      $("mailBills").checked = !!ME.mail?.bills; $("mailStreak").checked = !!ME.mail?.streak; $("mailWeekly").checked = !!ME.mail?.weekly;
      ["mailBills", "mailStreak", "mailWeekly"].forEach((id) => ($(id).disabled = !ME.verified));
      $("mailHint").hidden = !!ME.verified;
      drawShortcut(); drawPush(); drawPasskeys();
      applyTheme(store.get("hb-theme") || "dark");
      drawLangPickers();
      mailLinks();

      if (document.activeElement !== $("nestName")) $("nestName").value = NEST.name;
      const ks = $("kindSet"); ks.innerHTML = "";
      [["solo", "🐰", "Just me"], ["couple", "🐰🐻", "Couple"], ["family", "🐰🐻🐥", "Family"]].forEach(([id, e, n]) => {
        const b = document.createElement("button"); b.type = "button"; b.innerHTML = `<b>${e}</b>${n}`;
        b.setAttribute("aria-pressed", KIND() === id ? "true" : "false");
        b.onclick = async () => { NEST.kind = id; render(); try { await api("/api/nest", { method: "PATCH", body: { kind: id } }); } catch (err) { toast(err.message); } };
        ks.appendChild(b);
      });
      { const jr = $("jointRow"); jr.hidden = KIND() !== "couple" || MEMBERS.length < 2;
        const on = !!NEST.joint; $("jointState").textContent = tr(on ? "On" : "Off"); $("jointState").classList.toggle("on", on);
        jr.onclick = async () => { NEST.joint = NEST.joint ? 0 : 1; render(); try { await api("/api/nest", { method: "PATCH", body: { joint: !!NEST.joint } }); toast(tr(NEST.joint ? "Joint account is on. Everything adds up together." : "Joint account is off.")); } catch (err) { NEST.joint = NEST.joint ? 0 : 1; render(); toast(err.message); } }; }
      const mm = $("members"); mm.innerHTML = "";
      MEMBERS.forEach((m) => {
        const r = document.createElement("div"); r.className = "mem";
        r.innerHTML = `<span class="face" style="background:${esc(m.color)}">${esc(m.emoji)}</span><span class="nm">${esc(m.name)}${m.id === ME.id ? " (you)" : ""}</span>`;
        if (m.id === ME.id) { const b = document.createElement("button"); b.className = "small"; b.textContent = "Edit"; b.onclick = openMe; r.appendChild(b); }
        mm.appendChild(r);
      });
      drawSwatches($("swatches"));
      $("signedAs").textContent = "Signed in as " + ME.email;
      $("acctName").textContent = $("hi").textContent;
    }
    updBadges();
    syncTaskbar();
    fitDesktop();
  }

  // ---------- plan: budgets ----------
  function renderPlan() {
    const by = spentByCat(), box = $("budgets"), cats = Object.keys(BUDGETS);
    if (!cats.length) {
      box.innerHTML = `<p class="empty" style="margin:0;padding:4px 0 10px">Give each category a monthly limit, like $400 for groceries. We'll warn you before you go over.</p><button class="small" id="budStart">Set budgets</button>`;
      $("budStart").onclick = openBudgets;
    } else {
      const limOf = (c) => BUDGETS[c] + (CARRY[c] || 0) / 100;
      const totL = cats.reduce((s, c) => s + limOf(c), 0), totS = cats.reduce((s, c) => s + (by[c] || 0), 0), totC = cats.reduce((s, c) => s + (CARRY[c] || 0), 0) / 100;
      box.innerHTML = `<div class="bud"><div class="l"><span>All budgets</span><small class="${totS > totL ? "over" : ""}">${fmt(totS)} of ${fmt(totL)}${totC > 0 ? ` <span class="carry">(+${fmt(totC)} rolled over)</span>` : ""}</small></div>
        <div class="trk"><i class="${totS > totL ? "over" : totS > totL * 0.8 ? "warn" : ""}" style="width:${Math.min(100, (totS / totL) * 100)}%"></i></div></div>` +
        cats.map((c) => ({ c, lim: limOf(c), sp: by[c] || 0, carry: (CARRY[c] || 0) / 100 })).sort((a, b) => b.sp / b.lim - a.sp / a.lim).map((x) => {
          const r = x.sp / x.lim;
          return `<div class="bud"><div class="l"><span>${esc(catOf(x.c).n)}</span><small class="${r > 1 ? "over" : r > 0.8 ? "warnt" : ""}">${r > 1 ? "Over by " + fmt(x.sp - x.lim) : fmt(x.lim - x.sp) + " left of " + fmt(x.lim)}${x.carry > 0 ? ` <span class="carry">(+${fmt(x.carry)} rolled over)</span>` : ""}</small></div>
            <div class="trk"><i class="${r > 1 ? "over" : r > 0.8 ? "warn" : ""}" style="width:${Math.min(100, r * 100)}%"></i></div></div>`;
        }).join("");
    }
    renderCalendar();
    // bills list
    const bl = $("bills"); bl.innerHTML = "";
    { const up = MONTH === today().slice(0, 7) && RECUR.length ? upcoming() : null; const tot = up ? up.bills.reduce((a, b) => a + b.r.amount_cents / 100, 0) : 0;
      $("billsDueSub").textContent = up && up.bills.length ? `${fmt(tot)} due${up.payday ? " before " + shortDay(up.payday) : " soon"}` : ""; }
    // Subscriptions tab: repeating expenses in the Subscriptions category, with monthly and yearly totals
    const subs = RECUR.filter((r) => r.type === "expense" && r.category === "subs");
    const PER_MONTH = { weekly: 52 / 12, biweekly: 26 / 12, monthly: 1 };
    const subsOn = billsTab === "subs";
    $("tabBills").setAttribute("aria-selected", !subsOn); $("tabSubs").setAttribute("aria-selected", subsOn);
    $("subsCount").hidden = !subs.length; $("subsCount").textContent = subs.length;
    $("billsDueSub").hidden = subsOn;
    $("billsAddT").textContent = subsOn ? "Add a subscription" : "Add a bill or payday";
    $("subsSum").hidden = !subsOn || !subs.length;
    if (subsOn && subs.length) {
      const mo = subs.reduce((a, r) => a + (r.amount_cents / 100) * (PER_MONTH[r.freq] || 1), 0);
      const soon = subs.map((r) => ({ r, n: nextOcc(r) })).filter((x) => x.n).sort((a, b) => a.n - b.n)[0];
      $("subsSum").innerHTML = `<div><b>${fmt(mo)}</b><small>${esc(tr("a month"))}</small></div><div><b>${fmt(mo * 12).replace(/\.\d\d$/, "")}</b><small>${esc(tr("a year"))}</small></div>
        <div><b>${soon ? esc(shortDay(soon.n)) : "–"}</b><small>${soon ? esc(tr("next:") + " " + soon.r.label) : esc(tr("next charge"))}</small></div>`;
    }
    // soonest first; subscriptions live in their own tab, so Bills & paydays skips them
    const byNext = (list) => list.slice().sort((x, y) => (nextOcc(x) || Infinity) - (nextOcc(y) || Infinity));
    const rows = byNext(subsOn ? subs : RECUR.filter((r) => !(r.type === "expense" && r.category === "subs")));
    const sig = billsTab + "|" + rows.length;
    if (sig !== billsSig) { billsSig = sig; billsPage = 0; }
    const pages = Math.max(1, Math.ceil(rows.length / billsSize));
    billsPage = Math.min(billsPage, pages - 1);
    if (!rows.length) bl.innerHTML = subsOn
      ? `<li class="empty" style="justify-content:center;border:0;text-align:center">No subscriptions yet. Add Netflix, Spotify, your gym… and I'll remind you before each charge 🐰</li>`
      : `<li class="empty" style="justify-content:center;border:0">Rent, bills, paychecks. Add them once.</li>`;
    rows.slice(billsPage * billsSize, (billsPage + 1) * billsSize).forEach((r) => {
      const isIn = r.type === "income", n = nextOcc(r);
      const li = document.createElement("li"); li.className = "clickable";
      const yearly = subsOn ? ` · ${fmt((r.amount_cents / 100) * (PER_MONTH[r.freq] || 1) * 12).replace(/\.\d\d$/, "")}/${tr("yr")}` : "";
      li.innerHTML = `<div class="ic">${isIn ? incTile(38) : catTile(r.category, 38)}</div>
        <div class="mid"><div class="t">${esc(r.label)}</div><div class="s">${FREQ_NAME[r.freq]}${n ? ", next " + shortDay(n) : ""}${subsOn ? esc(yearly) : ", " + esc(member(r.member_id).name)}</div></div>
        <div class="amt ${isIn ? "in" : ""}">${isIn ? "+" : ""}${fmt(r.amount_cents / 100)}</div>`;
      li.onclick = () => openEditRecurring(r);
      bl.appendChild(li);
    });
    // pages + a pointer to the other tab
    const foot = $("billsFoot"); foot.innerHTML = "";
    if (pages > 1) {
      const pg = document.createElement("div"); pg.className = "due-pg";
      pg.innerHTML = `<button type="button" aria-label="${esc(tr("Previous page"))}" ${billsPage === 0 ? "disabled" : ""}>‹</button><span>${billsPage + 1} / ${pages}</span><button type="button" aria-label="${esc(tr("Next page"))}" ${billsPage >= pages - 1 ? "disabled" : ""}>›</button>`;
      const [pv, nx] = pg.querySelectorAll("button");
      pv.onclick = () => { billsPage--; render(); }; nx.onclick = () => { billsPage++; render(); };
      foot.appendChild(pg);
    }
    if (!subsOn && subs.length) {
      const l = document.createElement("button"); l.type = "button"; l.className = "linkbtn bills-subs-link";
      l.textContent = R(`${subs.length} subscription${subs.length > 1 ? "s" : ""} in the Subscriptions tab ›`, `${subs.length} suscripción${subs.length > 1 ? "es" : ""} en la pestaña Suscripciones ›`, `订阅标签里有 ${subs.length} 个订阅 ›`);
      l.onclick = () => { billsTab = "subs"; render(); };
      foot.appendChild(l);
    }
    renderGoals();
    renderDebts();
  }
  function openBudgets() {
    const box = $("budgetEdit"); box.innerHTML = "";
    CATS.forEach((c) => {
      const l = document.createElement("label");
      l.innerHTML = `${catTile(c.id, 30)} <span>${esc(c.n)}</span><input type="number" inputmode="decimal" min="0" step="1" data-cat="${c.id}" placeholder="No limit">`;
      l.querySelector("input").value = BUDGETS[c.id] ?? "";
      box.appendChild(l);
    });
    $("bdRollover").checked = !!NEST.rollover;
    $("bdErr").textContent = ""; $("budgetDlg").showModal();
  }
  $("editBudgets").onclick = openBudgets;
  $("bdCancel").onclick = () => $("budgetDlg").close();
  $("bdSave").onclick = async () => {
    const items = [...document.querySelectorAll("#budgetEdit input")].map((i) => ({ category: i.dataset.cat, limit: parseFloat(i.value) || 0 }));
    try { await api("/api/budgets", { method: "PUT", body: { items, rollover: $("bdRollover").checked } }); $("budgetDlg").close(); await loadNest(); toast("Budgets saved"); }
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
    if (!calSel) { dayBox.innerHTML = `<p class="hint phone-only" style="margin:0">Tap a day to see what's due. Pink dots are bills, green are paydays.</p><div class="cal-legend desk-only"><span><i></i>Bill</span><span><i class="in"></i>Payday</span><span class="r">Tap a day to see what's due</span></div>`; return; }
    const items = byDay[+calSel.slice(8)] || [];
    dayBox.innerHTML = `<p class="hint" style="margin:0 0 4px">${dayName(parseD(calSel))}</p>` + (items.length ? items.map((x) =>
      `<div><span>${esc(x.r.label)}</span><span>${x.r.type === "income" ? "+" : ""}${fmt(x.r.amount_cents / 100)} · ${x.paid ? "Done ✓" : x.d < parseD(t) ? "Overdue" : x.r.type === "income" ? "Expected" : "Due"}</span></div>`).join("")
      : `<p class="hint" style="margin:0">Nothing due this day.</p>`);
  }

  // ---------- plan: savings goals ----------
  function jarSvg(pct, fill, id) {
    const h = Math.round(34 * Math.min(100, pct) / 100), y = 44 - h;
    return `<svg viewBox="0 0 40 50" aria-hidden="true"><defs><clipPath id="jc${id}"><path d="M9 12h22q3 0 3 4v26q0 5-5 5H11q-5 0-5-5V16q0-4 3-4z"/></clipPath></defs>
      <rect x="0" y="${y}" width="40" height="${h + 8}" fill="${fill}" clip-path="url(#jc${id})"/>
      <path d="M9 12h22q3 0 3 4v26q0 5-5 5H11q-5 0-5-5V16q0-4 3-4z" fill="none" stroke="currentColor" stroke-width="1.8"/>
      <rect x="11" y="5" width="18" height="7" rx="2.5" fill="var(--card)" stroke="currentColor" stroke-width="1.8"/></svg>`;
  }
  function renderGoals() {
    const box = $("goals");
    box.className = "goals-grid"; box.innerHTML = "";
    const addTile = () => { const a = document.createElement("button"); a.className = "jar-add desk-only"; a.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg><span>Save for a trip, a ring, or a rainy day</span>`; a.onclick = () => $("addGoal").click(); box.appendChild(a); };
    if (!GOALS.length) { box.insertAdjacentHTML("beforeend", `<div class="panel pad phone-only"><p class="empty" style="margin:0">Save for a trip, a ring, or a rainy day. Tap New jar to start.</p></div>`); addTile(); return; }
    const fills = ["#F4D48A", "#A9DCC3", "#F6B8CB", "#BFD0F5", "#D2C6F3"];
    GOALS.forEach((g, i) => {
      const saved = g.saved_cents / 100, target = g.target_cents / 100, pct = target ? Math.min(100, (saved / target) * 100) : 0;
      const el = document.createElement("button"); el.className = "jar-card";
      el.innerHTML = `${jarSvg(pct, fills[i % fills.length], i)}<span class="tt"><span>${esc(g.name)}</span><b>${fmt(saved)}</b><small>${pct >= 100 ? "reached ♡" : "of " + fmt(target)}</small></span>`;
      el.onclick = () => openGoal(g);
      box.appendChild(el);
    });
    if (GOALS.length < 4) addTile();
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
    if (!DEBTS.length) { box.innerHTML = `<p class="empty phone-only" style="margin:0;padding:4px 0">Track credit cards, car loans, or student loans and see when you'll be debt-free.</p><div class="empty-row desk-only"><i><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M3 10h18"/></svg></i><span>Track credit cards, car loans, or student loans and see when you'll be debt-free.</span><button class="small" id="debtStart">Add debt</button></div>`; $("debtStart").onclick = () => $("addDebt").click(); return; }
    const left = DEBTS.reduce((s, d) => s + Math.max(0, d.start_cents - d.paid_cents), 0) / 100;
    const paid = DEBTS.reduce((s, d) => s + d.paid_cents, 0) / 100;
    const extra = parseFloat(store.get("hb-debt-extra") || "0") || 0;
    const plan = payoffPlan(extra);
    box.innerHTML = `<div class="strategy"><div class="split"><button type="button" data-s="snowball" aria-pressed="${debtStrat === "snowball"}">Snowball</button><button type="button" data-s="avalanche" aria-pressed="${debtStrat === "avalanche"}">Avalanche</button></div></div>
      <p class="hint" style="margin:0 0 8px">${debtStrat === "snowball" ? "Pay the smallest balance first for quick wins." : "Pay the highest interest first to save the most money."}</p>
      <label class="extra"><span class="x-l">Extra each month $</span><input id="debtExtra" type="number" inputmode="decimal" min="0" step="10" value="${extra || ""}" placeholder="${matchMedia("(min-width: 900px)").matches ? esc(tr("Extra $/mo")) : "0"}" aria-label="${esc(tr("Extra each month $"))}"></label>
      <div class="payoff">${left <= 0 ? "Everything's paid off 🎉" : plan.months === null ? "Add minimum payments to see your debt-free date." : `<b>${fmt(left)}</b> left · debt-free around <b>${monthsOut(plan.months)}</b>`}${paid > 0 ? `<br><span style="color:var(--soft)">${fmt(paid)} paid so far</span>` : ""}</div>`;
    box.querySelectorAll("[data-s]").forEach((b) => (b.onclick = () => { debtStrat = b.dataset.s; store.set("hb-debt-strat", debtStrat); renderDebts(); }));
    $("debtExtra").onchange = (e) => { store.set("hb-debt-extra", String(parseFloat(e.target.value) || 0)); renderDebts(); };
    const sorted = [...DEBTS].sort((a, b) => {
      const ia = plan.order.indexOf(a.id), ib = plan.order.indexOf(b.id);
      return (ia < 0 ? 999 : ia) - (ib < 0 ? 999 : ib);
    });
    // desktop: a page of debts at a time so the card never pushes Plan into scrolling (phones show them all)
    const deskPaged = matchMedia("(min-width: 900px)").matches;
    const dsig = "d" + sorted.length; if (dsig !== debtSig) { debtSig = dsig; debtPage = 0; }
    const dpages = deskPaged ? Math.max(1, Math.ceil(sorted.length / debtSize)) : 1;
    debtPage = Math.min(debtPage, dpages - 1);
    const shownDebts = deskPaged ? sorted.slice(debtPage * debtSize, (debtPage + 1) * debtSize) : sorted;
    shownDebts.forEach((d) => {
      const i = sorted.indexOf(d);
      const rem = Math.max(0, d.start_cents - d.paid_cents) / 100, pct = d.start_cents ? Math.min(100, (d.paid_cents / d.start_cents) * 100) : 0;
      const el = document.createElement("div"); el.className = "goal debt";
      el.innerHTML = `<span class="em">${rem <= 0 ? tileHtml("party", "green", 38) : tileHtml("card", "rose", 38)}</span><div class="mid"><div class="t"><span>${rem > 0 ? `${i + 1}. ` : ""}${esc(d.name)}</span><small title="${esc(tr("left"))}">${fmt(rem)}<span class="lft"> ${esc(tr("left"))}</span></small></div>
        <div class="s">${(d.apr_bp / 100).toFixed(2).replace(/\.00$/, "")}% APR · min ${fmt(d.min_cents / 100)}${plan.done[d.id] ? " · paid off ~" + monthsOut(plan.done[d.id]) : ""}</div>
        <div class="trk"><i style="width:${pct}%"></i></div></div>${rem > 0 ? '<button class="mini inc">Pay</button>' : ""}`;
      el.onclick = () => openDebt(d);
      const pb = el.querySelector("button"); if (pb) pb.onclick = (ev) => { ev.stopPropagation(); openPay(d); };
      box.appendChild(el);
    });
    if (dpages > 1) {
      const pg = document.createElement("div"); pg.className = "due-pg";
      pg.innerHTML = `<button type="button" aria-label="${esc(tr("Previous page"))}" ${debtPage === 0 ? "disabled" : ""}>‹</button><span>${debtPage + 1} / ${dpages}</span><button type="button" aria-label="${esc(tr("Next page"))}" ${debtPage >= dpages - 1 ? "disabled" : ""}>›</button>`;
      const [pv, nx] = pg.querySelectorAll("button");
      pv.onclick = () => { debtPage--; renderDebts(); fitDesktop(); }; nx.onclick = () => { debtPage++; renderDebts(); fitDesktop(); };
      box.appendChild(pg);
    }
    if (DEBTPAYS.length) {
      const h = document.createElement("ul"); h.className = "hist";
      DEBTPAYS.slice(0, deskPaged ? 1 : 5).forEach((p) => {
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
  let whereMode = "month";
  $("stWhM").onclick = () => { whereMode = "month"; renderStats(); };
  $("stWhY").onclick = () => { whereMode = "year"; if (!YDATA) loadYear(); renderStats(); };
  $("stYearBtn").onclick = () => { $("yearDlg").showModal(); if (!YDATA) loadYear(); };
  $("yearClose").onclick = () => $("yearDlg").close();
  function renderHopCal() {
    const [y, mo] = MONTH.split("-").map(Number), first = new Date(y, mo - 1, 1), days = new Date(y, mo, 0).getDate();
    const lead = (first.getDay() + 6) % 7, t = today(), isNow = MONTH === t.slice(0, 7), past = MONTH < t.slice(0, 7);
    const spend = {};
    ENTRIES.filter((e) => e.type === "expense" && !e.pending).forEach((e) => (spend[e.date] = (spend[e.date] || 0) + e.amount));
    // dot size by rank, so one big bill (rent) doesn't shrink every other day to a speck
    const sorted = Object.values(spend).filter((v) => v > 0).sort((a, b) => a - b);
    const rank = (v) => (sorted.length < 2 ? 1 : sorted.indexOf(v) / (sorted.length - 1));
    $("stWd").innerHTML = [0, 1, 2, 3, 4, 5, 6].map((i) => `<span>${esc(addDays(new Date(2024, 0, 1), i).toLocaleDateString(LOCALE, { weekday: "short" }))}</span>`).join("");
    const cal = $("stCal"); cal.innerHTML = "";
    const cells = Math.ceil((lead + days) / 7) * 7;
    let noSpend = 0, big = null;
    for (let i = 0; i < cells; i++) {
      const n = i - lead + 1, b = document.createElement("button"); b.type = "button"; b.className = "st-day";
      if (n < 1 || n > days) { b.classList.add("out"); b.tabIndex = -1; b.setAttribute("aria-hidden", "true"); cal.appendChild(b); continue; }
      const ds = `${MONTH}-${String(n).padStart(2, "0")}`, sp = spend[ds] || 0, done = past || (isNow && ds <= t);
      if (!done && !past) b.classList.add("future");
      if (ds === t) b.classList.add("today");
      let inner = `<span class="n">${n}</span>`;
      if (done && !sp) { noSpend++; inner += icon("paw"); }
      else if (sp) {
        const r = rank(sp);
        inner += `<span class="dot" style="--r:${r.toFixed(2)};opacity:${0.55 + r * 0.45}"></span><span class="amt">${esc(fmt(sp).replace(/\.\d\d$/, ""))}</span>`;
        if (!big || sp > big.sp) big = { ds, sp };
      }
      b.innerHTML = inner;
      const label = parseD(ds).toLocaleDateString(LOCALE, { weekday: "short", month: "short", day: "numeric" });
      b.setAttribute("aria-label", `${label}: ${sp ? fmt(sp) : done ? tr("no spending") : ""}`);
      if (done || sp) b.onclick = () => {
        const list = ENTRIES.filter((e) => e.date === ds && e.type === "expense");
        toast(list.length ? `${label}: ${list.slice(0, 3).map((e) => e.label).join(", ")}${list.length > 3 ? ` +${list.length - 3}` : ""} · ${fmt(sp)}` : `${label}: ${tr("no spending")} 🐾`);
      };
      cal.appendChild(b);
    }
    // calmest full week (Mon–Sun) so far this month
    let calm = null;
    for (let s0 = 1 - lead; s0 <= days; s0 += 7) {
      const a = Math.max(1, s0), z = Math.min(days, s0 + 6), end = `${MONTH}-${String(z).padStart(2, "0")}`;
      if (z - a < 6 || (!past && !(isNow && end <= t))) continue;
      let tot = 0; for (let d = a; d <= z; d++) tot += spend[`${MONTH}-${String(d).padStart(2, "0")}`] || 0;
      if (!calm || tot < calm.tot) calm = { a, z, tot };
    }
    const mn = (d) => parseD(`${MONTH}-${String(d).padStart(2, "0")}`).toLocaleDateString(LOCALE, { month: "short", day: "numeric" });
    $("stSum").innerHTML = `<div class="g"><b>${noSpend}</b><small>${esc(tr("no-spend days"))}</small></div>
      <div><b>${calm ? esc(`${mn(calm.a)}–${calm.z}`) : "–"}</b><small>${esc(tr("calmest week"))}</small></div>
      <div class="h"><b>${big ? esc(fmt(big.sp).replace(/\.\d\d$/, "")) : "–"}</b><small>${big ? esc(tr("biggest day") + ", " + mn(+big.ds.slice(8))) : esc(tr("biggest day"))}</small></div>`;
  }
  function renderStats() {
    renderBurrow();
    renderHopCal();
    $("stSub").textContent = tr(`${monthName(MONTH)} at a glance.`);
    $("yearLbl").textContent = YEAR;
    const ents = YDATA ? YDATA.entries : [];
    const inc = Array(12).fill(0), out = Array(12).fill(0), yc = {};
    ents.forEach((e) => {
      const m = +e.date.slice(5, 7) - 1, a = e.amount_cents / 100;
      if (e.type === "income") inc[m] += a; else { out[m] += a; yc[e.category] = (yc[e.category] || 0) + a; }
    });
    const ti = inc.reduce((a, b) => a + b, 0), to = out.reduce((a, b) => a + b, 0);
    $("yIn").textContent = fmt(ti); $("yOut").textContent = fmt(to); $("yKeep").textContent = ti ? Math.round(((ti - to) / ti) * 100) + "%" : "–";
    const W = 340, H = 150, top = Math.max(1, ...inc, ...out), gw = W / 12, bw = 9;
    let svg = `<svg viewBox="0 0 ${W} ${H + 18}" role="img" aria-label="Earned and spent by month">`;
    for (let i = 0; i < 12; i++) {
      const x = i * gw + gw / 2, hi = (inc[i] / top) * H, ho = (out[i] / top) * H, name = new Date(YEAR, i, 1).toLocaleDateString(LOCALE, { month: "short" });
      svg += `<rect x="${x - bw - 1}" y="${H - hi}" width="${bw}" height="${Math.max(hi, 1.5)}" rx="3" fill="var(--mint)" opacity="${inc[i] ? 1 : 0.25}"><title>${name}: earned ${fmt(inc[i])}</title></rect>`;
      svg += `<rect x="${x + 1}" y="${H - ho}" width="${bw}" height="${Math.max(ho, 1.5)}" rx="3" fill="var(--pink)" opacity="${out[i] ? 1 : 0.25}"><title>${name}: spent ${fmt(out[i])}</title></rect>`;
      svg += `<text x="${x}" y="${H + 14}" text-anchor="middle" font-size="9" font-weight="700" fill="var(--soft)">${LANG === "zh" ? i + 1 : name.slice(0, 1).toUpperCase()}</text>`;
    }
    $("yChart").innerHTML = svg + "</svg>";
    // where it went: month or year, top 5 + everything else
    const by = spentByCat(), data = whereMode === "year" ? yc : by;
    $("stWhM").setAttribute("aria-selected", whereMode === "month"); $("stWhY").setAttribute("aria-selected", whereMode === "year");
    const total = Object.values(data).reduce((a, b) => a + b, 0);
    $("barsMonth").textContent = total ? `${fmt(total)} · ${whereMode === "year" ? YEAR : monthName(MONTH)}` : "";
    const rows = CATS.filter((c) => data[c.id]).sort((a, b) => data[b.id] - data[a.id]);
    const shown = rows.slice(0, 5), rest = rows.slice(5).reduce((a, c) => a + data[c.id], 0), mx = Math.max(1, ...shown.map((c) => data[c.id]), rest);
    $("bars").innerHTML = !rows.length ? `<p class="empty" style="margin:0">${esc(whereMode === "year" && !YDATA ? tr("Loading…") : tr("No spending yet."))}</p>`
      : shown.map((c) => `<div class="bar"><div class="l"><span>${esc(tr(c.n))}</span><span>${fmt(data[c.id])}</span></div><div class="trk"><i style="width:${(data[c.id] / mx) * 100}%;background:${c.c}"></i></div></div>`).join("")
        + (rest ? `<div class="bar"><div class="l"><span>${esc(tr("Everything else"))}</span><span>${fmt(rest)}</span></div><div class="trk"><i style="width:${(rest / mx) * 100}%;background:var(--soft)"></i></div></div>` : "");
    // 50/30/20 in one line for the selected month
    const mInc = ENTRIES.filter((e) => e.type === "income").reduce((a, e) => a + e.amount, 0);
    const needs = NEEDS.reduce((a, c) => a + (by[c] || 0), 0), wants = WANTS.reduce((a, c) => a + (by[c] || 0), 0);
    if (!mInc) $("rule").innerHTML = `<p>${esc(tr("Add this month's income to see your 50 / 30 / 20 split."))}</p>`;
    else {
      const sav = Math.max(0, mInc - needs - wants), pc = (v) => Math.round((v / mInc) * 100);
      const ok = pc(needs) <= 55 && pc(wants) <= 35;
      $("rule").innerHTML = `<div class="top"><span>50 / 30 / 20</span><span class="${ok ? "ok" : "warn"}">${esc(tr(ok ? "On track" : pc(needs) > 55 ? "Needs are high" : "Wants are high"))}</span></div>
        <div class="stack"><i style="width:${Math.min(100, pc(needs))}%;background:#9BB8FF"></i><i style="width:${Math.min(100, pc(wants))}%;background:var(--pink)"></i><i style="width:${Math.min(100, pc(sav))}%;background:var(--mint)"></i></div>
        <div class="lg"><span>${esc(tr("Needs"))} ${pc(needs)}%</span><span>${esc(tr("Wants"))} ${pc(wants)}%</span><span>${esc(tr("Saved"))} ${pc(sav)}%</span></div>`;
    }
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
    mode = opts.type || "expense"; cat = opts.cat || "groc"; who = ME.id; shared = MEMBERS.length > 1; splitMode = "equal";
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
  $("billsAdd").onclick = () => openAdd(billsTab === "subs" ? { repeat: "monthly", cat: "subs" } : { repeat: "monthly" });
  $("tabBills").onclick = () => { billsTab = "bills"; render(); };
  $("tabSubs").onclick = () => { billsTab = "subs"; render(); };

  function renderForm() {
    const isInc = mode === "income", rep = $("repeat").value, editingRec = editing?.kind === "recurring";
    $("editBar").hidden = !editing;
    $("editTitle").textContent = editingRec ? (isInc ? "Edit payday" : "Edit bill") : "Edit entry";
    document.querySelectorAll("#scr-add .tabs button").forEach((b) => b.setAttribute("aria-selected", b.dataset.t === mode ? "true" : "false"));

    // one-tap repeats: your most common expenses, tap to log again
    const showRep = !isInc && !editing && !rep && REPEATS.length > 0;
    $("repeatsField").hidden = !showRep;
    if (showRep) {
      const box = $("repeats"); box.innerHTML = "";
      REPEATS.forEach((r) => {
        const b = document.createElement("button"); b.type = "button";
        b.innerHTML = `${catTile(r.category || "other", 32)}<span><b></b><small></small></span>`;
        b.querySelector("b").textContent = r.label;
        b.querySelector("small").textContent = fmt(r.amount_cents / 100) + (r.shared ? " · " + tr("split") : "");
        b.setAttribute("aria-label", tr("Log") + " " + r.label + " " + fmt(r.amount_cents / 100));
        b.onclick = () => logRepeat(r, b);
        box.appendChild(b);
      });
    }

    const c = $("cats"); c.innerHTML = "";
    CATS.forEach((k) => {
      const b = document.createElement("button"); b.type = "button"; b.innerHTML = `${catTile(k.id, 54)}<span>${k.n}</span>`;
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
    const canSplit = !isInc && MEMBERS.length > 1 && !JOINT();
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

    const hasAmt = parseFloat($("amt").value) > 0;
    $("goBtn").disabled = !hasAmt;
    $("goBtn").textContent = !hasAmt ? "Type an amount above $0 first" : editing ? "Save changes" : rep ? (isInc ? "Add payday" : "Add bill") : isInc ? "Add income" : "Add expense";
    $("goBtn").classList.toggle("inc", isInc);
  }
  document.querySelectorAll("#scr-add .tabs button").forEach((b) => (b.onclick = () => { mode = b.dataset.t; $("err").textContent = ""; renderForm(); }));
  $("spShared").onclick = () => { shared = true; renderForm(); };
  $("spMine").onclick = () => { shared = false; renderForm(); };
  document.querySelectorAll("#splitModes button").forEach((b) => (b.onclick = () => { splitMode = b.dataset.mode; $("splitVal").value = ""; renderForm(); if (splitMode !== "equal") $("splitVal").focus(); }));
  $("splitVal").oninput = () => { if (splitMode === "percent") renderForm(); };
  $("amt").addEventListener("input", () => { if (screen === "add") renderForm(); });
  $("repeat").onchange = () => { $("paidNow").checked = $("dt").value <= today(); renderForm(); };
  $("dt").onchange = () => { if ($("repeat").value && !editing) $("paidNow").checked = $("dt").value <= today(); };

  async function logRepeat(r, btn) {
    if (busyRepeat) return; busyRepeat = true;
    document.querySelectorAll("#repeats button").forEach((b) => (b.disabled = true));
    mode = "expense"; cat = r.category || "other"; who = ME.id; shared = !!r.shared && MEMBERS.length > 1; splitMode = r.split_mode || "equal";
    $("amt").value = (r.amount_cents / 100).toFixed(2); $("lbl").value = r.label;
    $("splitVal").value = r.split_mode === "owed" ? (r.split_value / 100).toFixed(2) : r.split_mode === "percent" ? r.split_value : "";
    $("priv").checked = !!r.private; $("repeat").value = ""; $("dt").value = today();
    renderForm();
    try { await submitEntry(); } finally { busyRepeat = false; document.querySelectorAll("#repeats button").forEach((b) => (b.disabled = false)); }
  }
  let busyRepeat = false;
  $("goBtn").onclick = () => submitEntry();
  async function submitEntry() {
    const amount = parseFloat($("amt").value);
    if (!(amount > 0)) { $("err").textContent = "Type an amount above $0 first."; $("amt").focus(); return; }
    const rep = $("repeat").value, isShared = mode === "expense" && shared && MEMBERS.length > 1 && !JOINT();
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
        if (res.queued) toast("Saved offline. It'll sync when you're back.");
        else rewardToast(res.reward, `${label} · ${fmt(amount)}`, res.id ? async () => {
          try { await api("/api/entries/" + res.id, { method: "DELETE" }); await loadNest(); toast("Undone"); } catch (e) { toast(e.message); }
        } : null);
        show("home"); bunnyHop();
      }
    } catch (e) { $("err").textContent = e.message; }
    finally { busy($("goBtn"), false); }
  }
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

  // ---------- appearance ----------
  function applyTheme(v) {
    if (v === "light" || v === "dark") document.documentElement.setAttribute("data-theme", v); else document.documentElement.removeAttribute("data-theme");
    store.set("hb-theme", v === "light" || v === "dark" ? v : "auto");
    const dark = v === "dark" || (v !== "light" && matchMedia("(prefers-color-scheme: dark)").matches);
    document.querySelector('meta[name="theme-color"]')?.setAttribute("content", dark ? "#1D1B21" : "#F6F5F8");
    document.querySelectorAll("#themePick button").forEach((b) => b.setAttribute("aria-pressed", b.dataset.themeOpt === (store.get("hb-theme") || "dark") ? "true" : "false"));
    if (window.hbHalloweenRefresh) window.hbHalloweenRefresh(); // Halloween only shows in a dark theme
  }
  document.querySelectorAll("#themePick button").forEach((b) => (b.onclick = () => applyTheme(b.dataset.themeOpt)));
  applyTheme(store.get("hb-theme") || "dark");
  matchMedia("(prefers-color-scheme: dark)").addEventListener?.("change", () => applyTheme(store.get("hb-theme") || "dark"));

  // ---------- passkeys ----------
  const bufB64u = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const b64uBuf = (s) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4)), (c) => c.charCodeAt(0));
  function hasPasskeys() { return !!(window.PublicKeyCredential && navigator.credentials && isSecureContext); }
  function deviceName() {
    const ua = navigator.userAgent;
    if (/iPhone/.test(ua)) return "iPhone"; if (/iPad/.test(ua)) return "iPad"; if (/Android/.test(ua)) return "Android phone";
    if (/Mac/.test(ua)) return "Mac"; if (/Windows/.test(ua)) return "Windows PC"; if (/CrOS/.test(ua)) return "Chromebook"; return "This device";
  }
  async function passkeyLogin() {
    const btn = $("passkeyLogin"); busy(btn, true); $("authErr").textContent = "";
    try {
      const o = await api("/api/passkeys/login/options", { method: "POST" });
      const cred = await navigator.credentials.get({ publicKey: { challenge: b64uBuf(o.challenge), rpId: o.rpId, timeout: o.timeout, userVerification: o.userVerification, allowCredentials: [] } });
      const r = cred.response;
      await api("/api/passkeys/login", { method: "POST", body: { id: cred.id, clientDataJSON: bufB64u(r.clientDataJSON), authenticatorData: bufB64u(r.authenticatorData), signature: bufB64u(r.signature) } });
      await afterAuth();
    } catch (e) {
      if (e.name === "NotAllowedError" || e.name === "AbortError") $("authErr").textContent = "";
      else $("authErr").textContent = e.message || "That didn't work. Try your password instead.";
    } finally { busy(btn, false); }
  }
  $("passkeyLogin").onclick = passkeyLogin;
  async function addPasskey() {
    $("pkErr").textContent = ""; busy($("pkAdd"), true);
    try {
      const o = await api("/api/passkeys/options", { method: "POST" });
      const pub = { ...o, challenge: b64uBuf(o.challenge), user: { ...o.user, id: b64uBuf(o.user.id) }, excludeCredentials: o.excludeCredentials.map((c) => ({ ...c, id: b64uBuf(c.id) })) };
      const cred = await navigator.credentials.create({ publicKey: pub });
      const r = cred.response;
      if (!r.getPublicKey) throw new Error("This browser is too old for passkeys here. Try updating it.");
      await api("/api/passkeys", { method: "POST", body: { id: cred.id, publicKey: bufB64u(r.getPublicKey()), alg: r.getPublicKeyAlgorithm(), clientDataJSON: bufB64u(r.clientDataJSON), authenticatorData: bufB64u(r.getAuthenticatorData()), name: deviceName() } });
      toast("Passkey added ♡"); await drawPasskeys();
    } catch (e) {
      if (e.name === "InvalidStateError") $("pkErr").textContent = "This device already has a passkey for your account.";
      else if (e.name !== "NotAllowedError" && e.name !== "AbortError") $("pkErr").textContent = e.message;
    } finally { busy($("pkAdd"), false); }
  }
  async function drawPasskeys() {
    const ok = hasPasskeys();
    $("pkUnsupported").hidden = ok; $("pkAdd").hidden = !ok;
    try { PASSKEYS = (await api("/api/passkeys")).passkeys; } catch { PASSKEYS = []; }
    const l = $("pkList"); l.innerHTML = "";
    $("pkNone").hidden = PASSKEYS.length > 0;
    PASSKEYS.forEach((k) => {
      const li = document.createElement("li");
      li.innerHTML = `<div class="mid"><div class="t"></div><div class="s"></div></div><button aria-label="Remove">✕</button>`;
      li.querySelector(".t").textContent = k.name;
      li.querySelector(".s").textContent = tr("Added") + " " + shortDay(parseD(new Date(k.created_at * 1000).toISOString().slice(0, 10))) + (k.last_used ? " · " + tr("last used") + " " + shortDay(parseD(new Date(k.last_used * 1000).toISOString().slice(0, 10))) : "");
      li.querySelector("button").onclick = async () => {
        if (!(await ask(tr("Remove this passkey?"), tr("You can still log in with your password or another passkey."), tr("Remove")))) return;
        try { await api("/api/passkeys/" + encodeURIComponent(k.id), { method: "DELETE" }); await drawPasskeys(); } catch (e) { $("pkErr").textContent = e.message; }
      };
      l.appendChild(li);
    });
    if (document.getElementById("passkeySub")) $("passkeySub").textContent = PASSKEYS.length ? PASSKEYS.length + " " + tr(PASSKEYS.length === 1 ? "passkey" : "passkeys") : tr("Log in with Face ID, Touch ID, or your phone");
  }
  $("openPasskeys").onclick = async () => { $("pkErr").textContent = ""; $("passkeyDlg").showModal(); await drawPasskeys(); };
  $("pkAdd").onclick = addPasskey;
  $("pkClose").onclick = () => $("passkeyDlg").close();

  // ---------- push notifications ----------
  const hasPush = () => "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
  async function drawPush() {
    const iosNoPwa = /iPhone|iPad/.test(navigator.userAgent) && !navigator.standalone;
    $("pushHint").hidden = !(iosNoPwa && !hasPush());
    $("pushToggle").disabled = !hasPush();
    if (!hasPush()) { $("pushToggle").checked = false; return; }
    try { const reg = await navigator.serviceWorker.ready; $("pushToggle").checked = !!(await reg.pushManager.getSubscription()) && Notification.permission === "granted"; }
    catch { $("pushToggle").checked = false; }
  }
  $("pushToggle").onchange = async () => {
    const on = $("pushToggle").checked;
    try {
      const reg = await navigator.serviceWorker.ready;
      if (on) {
        if ((await Notification.requestPermission()) !== "granted") { $("pushToggle").checked = false; toast("Notifications are blocked for Honeybun in your browser settings."); return; }
        const { key } = await api("/api/push/key");
        if (!key) throw new Error("Push isn't set up on the server yet.");
        const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64uBuf(key) });
        await api("/api/push/subscribe", { method: "POST", body: { endpoint: sub.endpoint } });
        toast("Push is on for this device 🐰");
      } else {
        const sub = await reg.pushManager.getSubscription();
        if (sub) { await api("/api/push/subscribe", { method: "DELETE", body: { endpoint: sub.endpoint } }).catch(() => {}); await sub.unsubscribe(); }
        toast("Push is off for this device");
      }
    } catch (e) { $("pushToggle").checked = !on; toast(e.message); }
  };

  // ---------- Apple Pay auto-logging (iPhone Shortcut key) ----------
  function drawShortcut() {
    const k = ME.shortcut;
    $("scOff").hidden = !!k; $("scOn").hidden = !k;
    $("scUrl").textContent = location.origin + "/api/log";
    if (k) {
      const used = k.uses ? tr("Logged " + k.uses + " " + (k.uses === 1 ? "purchase" : "purchases") + " so far.") : tr("Nothing logged yet. Finish the Shortcut below and tap to pay once to test it.");
      const when = k.last_used ? " " + tr("Last one") + " " + shortDay(parseD(new Date(k.last_used * 1000).toISOString().slice(0, 10))) + "." : "";
      $("scStatus").textContent = tr("Your Shortcut key is on.") + " " + used + when;
    }
    if (document.getElementById("shortcutSub")) $("shortcutSub").textContent = k ? "On · " + (k.uses || 0) + " logged" : "Log every tap-to-pay with an iPhone Shortcut";
  }
  async function makeKey() {
    $("scErr").textContent = "";
    try {
      const r = await api("/api/shortcut/key", { method: "POST" });
      ME.shortcut = { created_at: Math.floor(Date.now() / 1000), last_used: null, uses: 0 };
      $("scKey").textContent = r.key; $("scNew").hidden = false; drawShortcut();
      $("scOn").querySelector("details").open = true;
    } catch (e) { $("scErr").textContent = e.message; }
  }
  $("openShortcut").onclick = () => { $("scNew").hidden = true; $("scKey").textContent = ""; $("scErr").textContent = ""; drawShortcut(); $("shortcutDlg").showModal(); };
  $("scMake").onclick = makeKey;
  $("scRenew").onclick = async () => { if (await ask(tr("Make a new key?"), tr("Your old key stops working, so update the Shortcut with the new one."), tr("New key"))) makeKey(); };
  $("scRevoke").onclick = async () => {
    if (!(await ask(tr("Turn off auto-logging?"), tr("Your Shortcut will stop working until you make a new key."), tr("Turn off")))) return;
    try { await api("/api/shortcut/key", { method: "DELETE" }); ME.shortcut = null; $("scNew").hidden = true; drawShortcut(); toast("Auto-logging is off"); }
    catch (e) { $("scErr").textContent = e.message; }
  };
  $("scCopy").onclick = async () => {
    try { await navigator.clipboard.writeText($("scKey").textContent); toast("Key copied"); }
    catch { const r = document.createRange(); r.selectNodeContents($("scKey")); getSelection().removeAllRanges(); getSelection().addRange(r); toast("Press and hold to copy"); }
  };
  $("scClose").onclick = () => $("shortcutDlg").close();

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

  // ---------- Fair share (couples only): who brought in what, who spent what ----------
  let sharePct = null, shareMode = "income";
  const sharePeople = () => { const me = meMember(), other = MEMBERS.find((m) => m.id !== me?.id); return me && other ? [me, other] : null; };
  function shareStats(m) {
    const mine = ENTRIES.filter((e) => e.member_id === m.id), sum = (t, f) => mine.filter((e) => e.type === t && (!f || f(e))).reduce((s, e) => s + e.amount, 0);
    const inc = sum("income"), out = sum("expense"), sh = sum("expense", (e) => e.shared);
    return { m, inc, out, sh, own: out - sh, left: inc - out };
  }
  const pctOf = (v, t) => (t > 0 ? Math.round((v / t) * 100) : 0);
  function shareBar(a, b, va, vb) {
    const t = va + vb, pa = t > 0 ? (va / t) * 100 : 50;
    return `<div class="sh-bar" aria-hidden="true"><i style="width:${t > 0 ? pa : 50}%;background:${esc(a.color)}"></i><i style="width:${t > 0 ? 100 - pa : 50}%;background:${esc(b.color)}"></i></div>` +
      `<div class="sh-legend"><span>${esc(a.name)} ${t > 0 ? pctOf(va, t) + "%" : "–"}</span><span>${esc(b.name)} ${t > 0 ? pctOf(vb, t) + "%" : "–"}</span></div>`;
  }
  function renderShare() {
    const box = $("shareBody");
    if (!box) return;
    const ppl = sharePeople();
    if (!ppl) {
      box.innerHTML = `<div class="card pad sh-empty">${esc(tr("Invite your partner to see who brings in and spends what."))}<p style="margin:14px 0 0"><button class="softbtn" id="shareInv">${esc(tr("Invite your partner"))}</button></p></div>`;
      $("shareInv").onclick = () => show("us");
      return;
    }
    const [A, B] = ppl.map(shareStats);
    const inc = A.inc + B.inc, out = A.out + B.out, S = A.sh + B.sh;
    const row = (x, v, sub) => `<div class="sh-row"><span class="av" style="background:${esc(x.m.color)}">${esc(x.m.emoji)}</span><span class="nm">${esc(x.m.name)}${x.m.id === ME?.id ? `<small>${esc(tr("You"))}</small>` : ""}</span><span class="amt">${fmt(v)}<small>${sub}</small></span></div>`;
    box.innerHTML =
      `<div class="sh-col"><section class="card pad sh-card"><h2>${esc(tr("Brought in"))}</h2><p class="sh-sub">${esc(monthName(MONTH, true))}</p>` +
        row(A, A.inc, pctOf(A.inc, inc) + "%") + row(B, B.inc, pctOf(B.inc, inc) + "%") + shareBar(A.m, B.m, A.inc, B.inc) +
        `<div class="sh-tot"><span>${esc(tr("Together"))}</span><span>${fmt(inc)}</span></div></section>` +
      `<section class="card pad sh-card"><h2>${esc(tr("Spent so far"))}</h2><p class="sh-sub">${esc(monthName(MONTH, true))}</p>` +
        row(A, A.out, JOINT() ? pctOf(A.out, out) + "%" : `${esc(tr("shared"))} ${fmt(A.sh)} · ${esc(tr("own"))} ${fmt(A.own)}`) + row(B, B.out, JOINT() ? pctOf(B.out, out) + "%" : `${esc(tr("shared"))} ${fmt(B.sh)} · ${esc(tr("own"))} ${fmt(B.own)}`) + shareBar(A.m, B.m, A.out, B.out) +
        `<div class="sh-tot"><span>${esc(tr("Together"))}</span><span>${fmt(out)}</span></div>` +
        `<p class="sh-note">${esc(tr("Private entries only count for the person who made them."))}</p></section></div>` +
      `<section class="card pad sh-card" id="shBrain"></section>`;
    if (JOINT()) {
      const el = $("shBrain"), left = inc - out;
      el.innerHTML = `<h2>${esc(tr("Joint account"))}</h2><p class="sh-sub">${esc(tr("One shared pot, so the numbers add up together."))}</p>` +
        `<div class="sh-row"><span class="nm">${esc(tr("Came in"))}</span><span class="amt">${fmt(inc)}</span></div><div class="sh-row"><span class="nm">${esc(tr("Spent"))}</span><span class="amt">${fmt(out)}</span></div>` +
        `<div class="sh-tot"><span>${esc(tr("Left"))}</span><span>${fmt(left)}</span></div>` +
        `<p class="sh-tip">${esc(A.m.name)} ${esc(tr("brings in"))} ${pctOf(A.inc, inc)}%, ${esc(B.m.name)} ${pctOf(B.inc, inc)}%.</p>`;
    } else drawShareBrain(A, B, inc, S);
  }
  function drawShareBrain(A, B, inc, S) {
    const el = $("shBrain");
    const incPct = inc > 0 ? Math.round((A.inc / inc) * 100) : 50, nowPct = S > 0 ? Math.round((A.sh / S) * 100) : 50;
    const pct = sharePct == null ? (shareMode === "even" ? 50 : shareMode === "now" ? nowPct : incPct) : sharePct;
    const payA = S * pct / 100, payB = S - payA;
    const leftA = A.inc - A.own - payA, leftB = B.inc - B.own - payB;
    const chip = (id, label) => `<button type="button" data-sm="${id}" aria-pressed="${shareMode === id && sharePct == null}">${esc(tr(label))}</button>`;
    el.innerHTML = `<h2>${esc(tr("Brainstorm: split the shared costs"))}</h2><p class="sh-sub">${esc(tr("Shared costs this month"))}: <b>${fmt(S)}</b></p>` +
      `<div class="sh-chips">${chip("even", "50 / 50")}${chip("income", "By income")}${chip("now", "As it is now")}</div>` +
      `<input class="sh-slider" id="shSlider" type="range" min="0" max="100" step="1" value="${pct}" aria-label="${esc(A.m.name)}">` +
      `<div class="sh-legend"><span>${esc(A.m.name)} ${pct}%</span><span>${esc(B.m.name)} ${100 - pct}%</span></div>` +
      `<div class="sh-row"><span class="av" style="background:${esc(A.m.color)}">${esc(A.m.emoji)}</span><span class="nm">${esc(A.m.name)}<small>${esc(tr("pays"))} ${fmt(payA)}</small></span><span class="amt">${fmt(leftA)}<small>${esc(tr("left over"))}</small></span></div>` +
      `<div class="sh-row"><span class="av" style="background:${esc(B.m.color)}">${esc(B.m.emoji)}</span><span class="nm">${esc(B.m.name)}<small>${esc(tr("pays"))} ${fmt(payB)}</small></span><span class="amt">${fmt(leftB)}<small>${esc(tr("left over"))}</small></span></div>` +
      (inc > 0 ? `<p class="sh-tip">${esc(A.m.name)} ${esc(tr("brings in"))} ${incPct}%, ${esc(B.m.name)} ${100 - incPct}%. ${esc(tr("Splitting shared costs the same way is one fair option, 50/50 is another. Slide to try your own."))}</p>` : `<p class="sh-tip">${esc(tr("Add some income to see what a fair split looks like."))}</p>`);
    el.querySelectorAll("[data-sm]").forEach((b) => (b.onclick = () => { shareMode = b.dataset.sm; sharePct = null; drawShareBrain(A, B, inc, S); }));
    $("shSlider").oninput = (ev) => { sharePct = +ev.target.value; const t = ev.target; drawShareBrain(A, B, inc, S); $("shSlider").focus(); };
  }

  // Desktop only: scale the 1440px layout up to fill wider screens (and slightly down on small laptops)
  function fitDesktop() {
    const w = window.innerWidth;
    const inApp = APP_SCREENS.includes(screen);
    // fit a 1440×900 design into the window by width AND height, so no screen needs to scroll
    const z = w >= 900 && inApp ? Math.min(1.6, Math.max(0.7, Math.min(w / 1440, window.innerHeight / 900))) : 0;
    const root = document.documentElement;
    root.style.zoom = z ? String(z) : "";
    root.style.setProperty("--app-h", z ? window.innerHeight / z + "px" : "100vh");
    if (!z || $("scr-" + screen)?.hidden) return;
    // all measuring below happens before the browser paints, so nothing flickers
    const el = document.scrollingElement, over = () => el.scrollHeight - el.clientHeight;
    if (screen === "home") {
      const ul = $("recent");
      while (over() > 1 && ul.children.length > 4) { ul.lastElementChild.remove(); ul.lastElementChild.remove(); }
      while (over() > 1 && dueSize > 3 && $("dueCard").querySelector(".due-pg")) { dueSize--; renderDue(lastDueLeft); }
    }
    if (screen === "plan" && over() > 1) {
      // shrink the debts list first (it's the tallest), then the bills list, one step at a time
      if (debtSize > 1 && $("debts").querySelector(".due-pg")) { debtSize--; renderDebts(); return fitDesktop(); }
      if (billsSize > 3 && $("billsFoot").querySelector(".due-pg")) { billsSize--; render(); return; }
    }
    if (screen === "us" && over() > 1 && listRows && pageSize > 4) {
      const li = $("list").firstElementChild, rowH = li ? li.getBoundingClientRect().height / z : 60;
      pageSize = Math.max(4, pageSize - Math.ceil(over() / rowH)); drawPaged(listRows, listKey);
    }
    // last resort: shrink this screen a little (never below 82%) instead of scrolling
    if (screen !== "inbox" && over() > 1) root.style.zoom = String(z * Math.max(0.82, el.clientHeight / el.scrollHeight - 0.004));
  }
  // resizing the window fires this dozens of times a second: wait for it to settle instead of re-laying out every frame
  let resizeTimer = 0;
  window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { pageSize = PAGE_SIZE; dueSize = 5; billsSize = 6; debtSize = 3; if (["us", "home", "plan"].includes(screen)) render(); else fitDesktop(); }, 120);
  });
  // Desktop only: move a few blocks into the columns the wide layout expects. Phones keep the original order.
  if (matchMedia("(min-width: 900px)").matches) {
    $("dueCard").after($("bunNote"));
    // Settings: three columns (account | notifications + preferences | data + about), footer moves into the header
    {
      const sc = $("scr-settings"), g = sc.querySelector(".grid2"), cards = [...g.children];
      const nc = document.createElement("div"); nc.className = "card pad blk set-notif";
      nc.innerHTML = '<div class="title"><h2>Notifications</h2><span>email &amp; push</span></div>';
      nc.appendChild($("mailBills").closest(".setting-row"));
      const cols = [0, 1, 2].map(() => { const d = document.createElement("div"); d.className = "set-col"; g.appendChild(d); return d; });
      $("openPasskeys").before($("rerunSetup"), $("openShortcut")); // money setup rows sit with the account, balancing the columns
      cols[0].append(cards[0]); cols[1].append(nc, cards[1]); cols[2].append(cards[2], cards[3]);
      g.classList.add("set-cols");
      const r = document.createElement("div"); r.className = "set-head-r";
      r.append($("signedAs"), sc.querySelector("[data-coffee-wrap]"));
      sc.querySelector(".pagehead").appendChild(r);
    }
  }
  $("hiBtn").onclick = () => show("settings");
  $("setBtn").onclick = () => show("settings");
  $("helpBtn").onclick = () => show("help");
  $("openHelp").onclick = () => show("help");
  $("openProfile").onclick = () => openMe();
  $("helpBun").onclick = () => openInbox();
  $("exportCsv2").onclick = async () => { if (!YDATA) { try { YDATA = await api("/api/year?year=" + YEAR); } catch (e) { toast(e.message); return; } } $("exportCsv").click(); };
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

  // ---------- Bun's inbox ----------
  const money = (c) => fmt((c || 0) / 100);
  const catName = (id) => tr(catOf(id).n);
  const dayDiff = (occ) => Math.round((parseD(occ) - parseD(today())) / 86400000);
  const MSG = {
    en: {
      welcome: (d) => `Hi ${d.name}! I'm Bun 🐰 I'll pop in here with bill reminders, paydays, and streak check-ins.`,
      bill_soon: (d, n) => `${d.label} (${money(d.amount)}) is due ${n === 1 ? "tomorrow" : `in ${n} days`} 🐰`,
      bill_today: (d) => `${d.label} (${money(d.amount)}) is due today. Tap Paid once it's done ✓`,
      bill_late: (d) => `${d.label} (${money(d.amount)}) was due ${shortDay(parseD(d.occ))}. Did it get paid?`,
      payday: (d) => `It's payday! ${d.label} (${money(d.amount)}) should land today 💰`,
      streak_risk: (d) => `Your ${d.n}-day streak ends at midnight 🐾 Log one thing to keep hopping!`,
      streak_milestone: (d) => `${d.n}-day hop streak! You're on a roll 🐾✨`,
      level: (d, _, title, unlock) => `Level ${d.level}! You're now a ${title}.${unlock ? ` I got ${unlock} to wear 🎀` : " Keep hopping!"}`,
      budget_warn: (d) => `Heads up: ${catName(d.cat)} is at ${Math.round((d.spent / d.limit) * 100)}% of its budget (${money(d.spent)} of ${money(d.limit)}) 🥕`,
      budget_over: (d) => `${catName(d.cat)} went over budget by ${money(d.over)}. No stress, next month is a fresh start ♡`,
      week: (d) => `Last week you spent ${money(d.spent)}${d.cat ? `, mostly on ${catName(d.cat).toLowerCase()}` : ""}. You earned ${d.xp} carrots 🥕`,
      goal_done: (d) => `You reached your "${d.goal}" goal! 🍯 So proud of you.`,
      debt_done: (d) => `${d.debt} is paid off! 🎉 One less thing to carry.`,
      joined: (d) => `${d.name} joined your budget 💞 Say hi!`,
      joint: (d) => d.on ? `${d.name} turned on Joint account. Everything now adds up together and nobody owes anybody.` : `${d.name} turned off Joint account. Splitting and balances are back.`,
      settled: (d) => d.you_paid ? `${d.name} marked your ${money(d.amount)} payment as received 💸` : `${d.name} marked ${money(d.amount)} as paid to you 💸`,
      shared_expense: (d) => `${d.name} added ${d.label} (${money(d.amount)}) and split it with you.`,
    },
    es: {
      welcome: (d) => `¡Hola, ${d.name}! Soy Bun 🐰 Aquí te avisaré de facturas, días de pago y tu racha.`,
      bill_soon: (d, n) => `${d.label} (${money(d.amount)}) vence ${n === 1 ? "mañana" : `en ${n} días`} 🐰`,
      bill_today: (d) => `${d.label} (${money(d.amount)}) vence hoy. Toca Pagado cuando esté listo ✓`,
      bill_late: (d) => `${d.label} (${money(d.amount)}) vencía el ${shortDay(parseD(d.occ))}. ¿Ya se pagó?`,
      payday: (d) => `¡Hoy es día de pago! ${d.label} (${money(d.amount)}) debería llegar hoy 💰`,
      streak_risk: (d) => `Tu racha de ${d.n} días termina a medianoche 🐾 ¡Registra algo para seguir brincando!`,
      streak_milestone: (d) => `¡Racha de ${d.n} días! Vas súper bien 🐾✨`,
      level: (d, _, title, unlock) => `¡Nivel ${d.level}! Ahora eres ${title}.${unlock ? ` Me dieron ${unlock} para ponerme 🎀` : " ¡Sigue brincando!"}`,
      budget_warn: (d) => `Ojo: ${catName(d.cat)} va en ${Math.round((d.spent / d.limit) * 100)}% de su presupuesto (${money(d.spent)} de ${money(d.limit)}) 🥕`,
      budget_over: (d) => `${catName(d.cat)} se pasó del presupuesto por ${money(d.over)}. Tranqui, el próximo mes empieza de nuevo ♡`,
      week: (d) => `La semana pasada gastaste ${money(d.spent)}${d.cat ? `, sobre todo en ${catName(d.cat).toLowerCase()}` : ""}. Ganaste ${d.xp} zanahorias 🥕`,
      goal_done: (d) => `¡Lograste tu meta "${d.goal}"! 🍯 Estoy muy orgulloso.`,
      debt_done: (d) => `¡${d.debt} está pagada! 🎉 Una carga menos.`,
      joined: (d) => `${d.name} se unió a tu presupuesto 💞 ¡Salúdalo!`,
      joint: (d) => d.on ? `${d.name} activó la cuenta conjunta. Todo se suma junto y nadie le debe a nadie.` : `${d.name} desactivó la cuenta conjunta. Vuelven la división y los saldos.`,
      settled: (d) => d.you_paid ? `${d.name} marcó tu pago de ${money(d.amount)} como recibido 💸` : `${d.name} marcó ${money(d.amount)} como pagado para ti 💸`,
      shared_expense: (d) => `${d.name} agregó ${d.label} (${money(d.amount)}) y lo dividió contigo.`,
    },
    zh: {
      welcome: (d) => `${d.name}，你好！我是 Bun 🐰 账单提醒、发薪日和连续记录，我都会在这里告诉你。`,
      bill_soon: (d, n) => `${d.label}（${money(d.amount)}）${n === 1 ? "明天" : `${n} 天后`}到期 🐰`,
      bill_today: (d) => `${d.label}（${money(d.amount)}）今天到期。付完后点「已付」✓`,
      bill_late: (d) => `${d.label}（${money(d.amount)}）原定 ${shortDay(parseD(d.occ))} 到期，付了吗？`,
      payday: (d) => `今天发薪啦！${d.label}（${money(d.amount)}）应该今天到账 💰`,
      streak_risk: (d) => `你的 ${d.n} 天连续记录将在午夜中断 🐾 记一笔继续保持吧！`,
      streak_milestone: (d) => `连续记录 ${d.n} 天！状态超棒 🐾✨`,
      level: (d, _, title, unlock) => `升到 ${d.level} 级啦！你现在是「${title}」。${unlock ? `我得到了${unlock} 🎀` : "继续加油！"}`,
      budget_warn: (d) => `提醒：${catName(d.cat)} 已用掉预算的 ${Math.round((d.spent / d.limit) * 100)}%（${money(d.spent)} / ${money(d.limit)}）🥕`,
      budget_over: (d) => `${catName(d.cat)} 超支了 ${money(d.over)}。别担心，下个月重新开始 ♡`,
      week: (d) => `上周你花了 ${money(d.spent)}${d.cat ? `，主要花在${catName(d.cat)}` : ""}。获得了 ${d.xp} 根胡萝卜 🥕`,
      goal_done: (d) => `你达成了「${d.goal}」目标！🍯 为你骄傲。`,
      debt_done: (d) => `「${d.debt}」还清啦！🎉 少了一份负担。`,
      joined: (d) => `${d.name} 加入了你的预算 💞 打个招呼吧！`,
      joint: (d) => d.on ? `${d.name} 开启了共同账户。所有金额合并计算，没人欠谁。` : `${d.name} 关闭了共同账户。分摊和结算恢复。`,
      settled: (d) => d.you_paid ? `${d.name} 确认收到了你的 ${money(d.amount)} 💸` : `${d.name} 标记已付给你 ${money(d.amount)} 💸`,
      shared_expense: (d) => `${d.name} 添加了 ${d.label}（${money(d.amount)}），和你一起分摊。`,
    },
  };
  {
    const A = (d) => fmt(((d && d.amount) || 1000) / 100).replace(/\.00$/, "");
    Object.assign(MSG.en, {
      ref_intro: (d) => `Psst 🎁 Share Honeybun with friends and earn a ${A(d)} gift card for every ${d.goal} who stick around for a week. Tap below for your link!`,
      ref_nudge: (d) => `Know someone who'd love a cute budget? Every ${d.goal} friends who join with your link = a ${A(d)} gift card 🎁`,
      ref_signup: (d) => `${d.name} just signed up with your link! 🎉 They'll count once they've used Honeybun for a week.`,
      ref_qualified: (d) => `${d.name} counts now! That's ${d.n} of ${d.goal} toward your next gift card 🥕`,
      reward_earned: (d) => `You did it! ${d.n} friends counted, so you earned a ${A(d)} gift card 🎁 It'll be emailed to you within a few days.`,
      reward_sent: (d) => `Your ${A(d)} gift card was sent! Check your email 💌 Thanks for sharing Honeybun.`,
    });
    Object.assign(MSG.es, {
      ref_intro: (d) => `Psst 🎁 Comparte Honeybun y gana una tarjeta de regalo de ${A(d)} por cada ${d.goal} amigos que se queden una semana. ¡Toca abajo para tu enlace!`,
      ref_nudge: (d) => `¿Conoces a alguien que amaría un presupuesto lindo? Cada ${d.goal} amigos con tu enlace = una tarjeta de ${A(d)} 🎁`,
      ref_signup: (d) => `¡${d.name} se registró con tu enlace! 🎉 Contará cuando use Honeybun por una semana.`,
      ref_qualified: (d) => `¡${d.name} ya cuenta! Llevas ${d.n} de ${d.goal} para tu próxima tarjeta 🥕`,
      reward_earned: (d) => `¡Lo lograste! ${d.n} amigos contaron y ganaste una tarjeta de ${A(d)} 🎁 Te llegará por correo en unos días.`,
      reward_sent: (d) => `¡Tu tarjeta de ${A(d)} fue enviada! Revisa tu correo 💌 Gracias por compartir Honeybun.`,
    });
    Object.assign(MSG.zh, {
      ref_intro: (d) => `悄悄告诉你 🎁 分享 Honeybun，每有 ${d.goal} 位好友使用满一周，你就能获得 ${A(d)} 礼品卡。点下面获取你的链接！`,
      ref_nudge: (d) => `身边有人想要可爱的记账本吗？每 ${d.goal} 位通过你链接加入的好友 = ${A(d)} 礼品卡 🎁`,
      ref_signup: (d) => `${d.name} 刚通过你的链接注册了！🎉 使用满一周后就会计入。`,
      ref_qualified: (d) => `${d.name} 已计入！距离下一张礼品卡：${d.n}/${d.goal} 🥕`,
      reward_earned: (d) => `你做到了！${d.n} 位好友已计入，你获得了 ${A(d)} 礼品卡 🎁 几天内会通过邮件发送给你。`,
      reward_sent: (d) => `你的 ${A(d)} 礼品卡已发送！请查收邮件 💌 感谢分享 Honeybun。`,
    });
  }
  function msgText(m) {
    const T = MSG[LANG] || MSG.en, d = m.data || {};
    let kind = m.kind, n = 0;
    if (["bill_soon", "bill_today", "bill_late"].includes(kind) && d.occ) {
      n = dayDiff(d.occ); kind = n < 0 ? "bill_late" : n === 0 ? "bill_today" : "bill_soon"; // keep the wording up to date
    }
    const l = d.level || 1;
    const fn = T[kind] || MSG.en[kind];
    return fn ? fn(d, n, tr(TITLES[Math.min(l, TITLES.length) - 1]), UNLOCKS[l] ? tr(UNLOCKS[l]) : null) : "";
  }
  function msgActions(m, box) {
    const d = m.data || {}, add = (label, cls, fn) => { const b = document.createElement("button"); b.className = "mini " + cls; b.textContent = tr(label); b.onclick = fn; box.appendChild(b); };
    if (["bill_soon", "bill_today", "bill_late", "payday"].includes(m.kind)) {
      const r = RECUR.find((x) => x.id === d.rid);
      if (!r) return;
      if (LOGGED.has(r.id + "|" + d.occ)) { box.insertAdjacentHTML("afterend", `<span class="ok">${esc(tr(m.kind === "payday" ? "Got it" : "Paid"))} ✓</span>`); return; }
      add(m.kind === "payday" ? "Got it" : "Paid", m.kind === "payday" ? "inc" : "", async (ev) => { await logOcc(r, parseD(d.occ), ev.currentTarget); drawChat(CHAT, false); });
    }
    if (m.kind === "streak_risk") add("Log something", "", () => openAdd());
    if (m.kind === "budget_warn" || m.kind === "budget_over") add("See budgets", "", () => show("plan"));
    if (m.kind === "goal_done" || m.kind === "debt_done") add("See Plan", "", () => show("plan"));
    if (m.kind === "week") add("See stats", "", () => show("stats"));
    if (m.kind === "level" || m.kind === "streak_milestone") add("See my bunny", "", () => show("stats"));
    if (["ref_intro", "ref_nudge"].includes(m.kind)) add("Get my link", "", () => show("refer"));
    if (["ref_signup", "ref_qualified", "reward_earned", "reward_sent"].includes(m.kind)) add("See referrals", "", () => show("refer"));
  }
  let CHAT = [];
  function drawChat(msgs, animateNew) {
    const box = $("chat"); box.innerHTML = "";
    if (!msgs.length) { box.innerHTML = `<div class="chat-empty">${esc(tr("No messages yet. I'll hop in when something's coming up 🐰"))}</div>`; return; }
    let lastDay = "", prevDay = null;
    const t = today(), y = yesterday();
    msgs.forEach((m, i) => {
      const dt = new Date(m.created_at * 1000), ds = toS(dt);
      if (ds !== lastDay) {
        lastDay = ds; prevDay = null;
        box.insertAdjacentHTML("beforeend", `<div class="chat-day">${esc(ds === t ? tr("Today") : ds === y ? tr("Yesterday") : dayName(dt))}</div>`);
      }
      const el = document.createElement("div");
      el.className = "msg" + (prevDay !== ds ? " first" : "") + (!m.read_at ? " new" : "") + (animateNew && !m.read_at ? " pop" : "");
      el.innerHTML = `<div class="av"><img src="/icon-192.png" alt=""></div><div class="b"><p></p><div class="acts"></div><time>${dt.toLocaleTimeString(LOCALE, { hour: "numeric", minute: "2-digit" })}</time></div>`;
      el.querySelector("p").textContent = msgText(m);
      msgActions(m, el.querySelector(".acts"));
      if (animateNew && !m.read_at) el.style.animationDelay = (i * 0.06) + "s";
      box.appendChild(el);
      prevDay = ds;
    });
  }
  function chatToEnd() { const c = $("chat"); if (getComputedStyle(c).overflowY === "auto") c.scrollTo({ top: c.scrollHeight, behavior: "smooth" }); else window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" }); }
  async function openInbox() {
    show("inbox");
    const box = $("chat");
    box.innerHTML = `<div class="msg first typing"><div class="av"><img src="/icon-192.png" alt=""></div><div class="b"><i></i><i></i><i></i></div></div>`;
    try {
      const [d] = await Promise.all([api("/api/inbox"), new Promise((r) => setTimeout(r, INBOX.unread ? 700 : 250))]);
      CHAT = d.messages;
      drawChat(CHAT, true);
      chatToEnd();
      if (CHAT.some((m) => !m.read_at)) {
        api("/api/inbox/read", { method: "POST" }).then(() => { INBOX = { unread: 0, latest: null }; CHAT.forEach((m) => (m.read_at = m.read_at || 1)); render(); syncTaskbar(); }).catch(() => {});
      }
    } catch (e) { box.innerHTML = `<div class="chat-empty">${esc(e.message)}</div>`; }
  }
  $("inboxBtn").onclick = openInbox;
  $("sideInbox").onclick = openInbox; $("sideHelp").onclick = () => show("help"); $("sideSet").onclick = () => show("settings"); $("sideHouse").onclick = () => show("settings");

  // email us (help + suggestions), with a little context so replies are easier
  function mailLinks() {
    const info = `\n\n— — —\n${tr("App info (helps us help you)")}: ${LANG} · ${KIND()} · ${navigator.userAgent.includes("iPhone") ? "iPhone" : navigator.userAgent.includes("Android") ? "Android" : "Web"}${ME ? " · " + ME.email : ""}`;
    const mk = (subject, body) => `mailto:help@honeybun.me?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body + info)}`;
    $("mailHelp").href = mk(tr("Honeybun help"), tr("Hi! I need help with:") + "\n\n");
    $("mailIdea").href = mk(tr("Honeybun suggestion"), tr("Hi! I have an idea for Honeybun:") + "\n\n");
  }
  $("inboxBack").onclick = () => show("home");
  $("qrDue").onclick = () => show("plan");
  $("qrStreak").onclick = () => show("stats");
  $("qrAdd").onclick = () => openAdd();
  $("heroPrev").onclick = () => shift(-1);
  $("heroNext").onclick = () => shift(1);

  // ---------- referrals: invite friends, earn gift cards ----------
  const R = (en, es, zh) => (LANG === "es" ? es : LANG === "zh" ? zh : en);
  let REF_FULL = null;
  const refAmt = (r) => fmt(((r && r.reward_cents) || 1000) / 100).replace(/\.00$/, "");
  const refInCycle = (r) => r.qualified % r.goal;
  function refPips(r, el, cls) {
    const got = refInCycle(r), wait = Math.min(r.pending, r.goal - got);
    el.innerHTML = Array.from({ length: r.goal }, (_, i) => `<i class="${i < got ? "on" : i < got + wait ? "wait" : i === r.goal - 1 && cls ? "gift" : ""}">${cls && i < got ? "✓" : cls && i === r.goal - 1 && i >= got + wait ? "🎁" : ""}</i>`).join("");
  }
  function refSub(r) {
    const got = refInCycle(r);
    if (!r.qualified && !r.pending) return R(`Invite ${r.goal} friends who stick around for a week`, `Invita a ${r.goal} amigos que se queden una semana`, `邀请 ${r.goal} 位好友使用满一周`);
    return R(`${got} of ${r.goal} counted`, `${got} de ${r.goal} cuentan`, `已计入 ${got}/${r.goal}`) + (r.pending ? R(` · ${r.pending} on the way`, ` · ${r.pending} en camino`, ` · ${r.pending} 位进行中`) : "");
  }
  function renderRefCard() {
    const r = ME && ME.ref, c = $("refCard");
    if (!r) { c.hidden = true; return; }
    c.hidden = false;
    $("refCardT").textContent = R(`Get a ${refAmt(r)} gift card`, `Gana una tarjeta de regalo de ${refAmt(r)}`, `赢取 ${refAmt(r)} 礼品卡`);
    $("refCardSub").textContent = refSub(r);
    refPips(r, $("refCardPips"));
    $("refNew").hidden = store.get("hb-ref-seen") === "1";
    $("refNew").textContent = R("NEW", "NUEVO", "新");
    c.onclick = () => { store.set("hb-ref-seen", "1"); show("refer"); };
  }
  function refLink(r) { return (REF_FULL && REF_FULL.link) || location.origin + "/r/" + r.code; }
  async function loadRef() {
    try {
      REF_FULL = await api("/api/referrals");
      ME.ref = { code: REF_FULL.code, goal: REF_FULL.goal, reward_cents: REF_FULL.reward_cents, qualified: REF_FULL.qualified, pending: REF_FULL.pending, rejected: REF_FULL.rejected };
      if (screen === "refer") renderRefer();
    } catch (e) { if (screen === "refer") $("refList").innerHTML = `<li class="ref-empty">${esc(e.message)}</li>`; }
  }
  const REF_WHY = {
    same_device: () => R("Signed up on your device", "Se registró en tu dispositivo", "在你的设备上注册"),
    same_household: () => R("Joined your own budget", "Se unió a tu propio presupuesto", "加入了你自己的预算"),
    inactive: () => R("Didn't stick around for a week", "No se quedó una semana", "没有坚持使用一周"),
    unverified: () => R("Never confirmed their email", "No confirmó su correo", "未确认邮箱"),
    left: () => R("Deleted their account", "Eliminó su cuenta", "已删除账户"),
  };
  function renderRefer() {
    const r = ME && ME.ref;
    if (!r) return;
    const amt = refAmt(r), full = REF_FULL, days = (full && full.days_needed) || 7, act = (full && full.active_days_needed) || 4;
    $("refH1").textContent = R("Invite friends", "Invita amigos", "邀请好友");
    $("refH1p").textContent = R("Share Honeybun and earn gift cards.", "Comparte Honeybun y gana tarjetas de regalo.", "分享 Honeybun，赢取礼品卡。");
    $("refHeroT").textContent = R(`Invite ${r.goal} friends, get a ${amt} gift card`, `Invita a ${r.goal} amigos y gana una tarjeta de ${amt}`, `邀请 ${r.goal} 位好友，得 ${amt} 礼品卡`);
    $("refHeroP").textContent = R(`When a friend signs up with your link and uses Honeybun for a week, they count. Every ${r.goal} friends = a ${amt} gift card, and there's no limit.`,
      `Cuando un amigo se registra con tu enlace y usa Honeybun por una semana, cuenta. Cada ${r.goal} amigos = una tarjeta de ${amt}, sin límite.`,
      `好友通过你的链接注册并使用 Honeybun 满一周即计入。每 ${r.goal} 位好友 = 一张 ${amt} 礼品卡，上不封顶。`);
    refPips(r, $("refDots"), true);
    const got = refInCycle(r), left = r.goal - got;
    $("refProg").textContent = r.qualified >= r.goal && got === 0
      ? R(`You earned ${r.qualified / r.goal} gift card${r.qualified / r.goal > 1 ? "s" : ""}! 🎉 Keep going for the next one.`, `¡Ganaste ${r.qualified / r.goal} tarjeta(s)! 🎉 Sigue por la próxima.`, `你已获得 ${r.qualified / r.goal} 张礼品卡！🎉 继续加油。`)
      : R(`${got} of ${r.goal} · ${left} more to your next gift card`, `${got} de ${r.goal} · faltan ${left} para tu próxima tarjeta`, `${got}/${r.goal} · 再邀请 ${left} 位即可获得礼品卡`);
    $("refLink").textContent = refLink(r).replace(/^https?:\/\//, "");
    $("refCopy").textContent = R("Copy", "Copiar", "复制");
    $("refShare").textContent = R("Share link", "Compartir", "分享链接"); $("refShare").hidden = !navigator.share;
    $("refText").textContent = R("Text a friend", "Enviar mensaje", "发短信");
    $("refAsk").textContent = R("Ask Bun 🐰", "Pregúntale a Bun 🐰", "问问 Bun 🐰");
    $("refHowT").textContent = R("How it works", "Cómo funciona", "如何运作");
    const steps = [
      [R("Share your link", "Comparte tu enlace", "分享你的链接"), R("Send it to friends, family, or post it anywhere.", "Envíalo a amigos o familia, o publícalo donde quieras.", "发给朋友、家人，或发布到任何地方。")],
      [R("They sign up", "Se registran", "他们注册"), R("They create a free account with your link and confirm their email. Bun tells you right away.", "Crean una cuenta gratis con tu enlace y confirman su correo. Bun te avisa al instante.", "他们用你的链接创建免费账户并确认邮箱，Bun 会立刻通知你。")],
      [R("They use it for a week", "La usan una semana", "使用满一周"), R(`Once they've logged on ${act} different days and are still using it after ${days} days, they count. Alone or with a partner, both work.`, `Cuando registran algo en ${act} días distintos y siguen usándola después de ${days} días, cuentan. Solos o en pareja.`, `当他们在 ${act} 个不同的日子记账，并且 ${days} 天后仍在使用时即计入。单人或情侣都可以。`)],
      [R(`Get your ${amt} gift card`, `Recibe tu tarjeta de ${amt}`, `领取 ${amt} 礼品卡`), R(`Every ${r.goal} friends who count = a ${amt} gift card, emailed to you.`, `Cada ${r.goal} amigos que cuentan = una tarjeta de ${amt} por correo.`, `每 ${r.goal} 位计入的好友 = 一张 ${amt} 礼品卡，通过邮件发送给你。`)],
    ];
    $("refSteps").innerHTML = steps.map(([t, d], i) => `<li><b>${i + 1}</b><span><strong>${esc(t)}</strong>${esc(d)}</span></li>`).join("");
    $("refFriendsT").textContent = R("Your friends", "Tus amigos", "你的好友");
    const ppl = full ? full.people : null;
    $("refCount").textContent = ppl ? R(`${ppl.length} signed up`, `${ppl.length} registrados`, `${ppl.length} 人已注册`) : "";
    const list = $("refList");
    if (!ppl) list.innerHTML = `<li class="ref-empty">${esc(R("Loading…", "Cargando…", "加载中…"))}</li>`;
    else if (!ppl.length) list.innerHTML = `<li class="ref-empty">${esc(R("No one yet. Share your link and Bun will let you know the moment someone joins 🐰", "Nadie aún. Comparte tu enlace y Bun te avisará cuando alguien se una 🐰", "还没有人。分享你的链接，有人加入时 Bun 会第一时间告诉你 🐰"))}</li>`;
    else list.innerHTML = ppl.map((p) => {
      const nm = p.name || R("Former member", "Ex miembro", "前成员"), day = Math.min(days, Math.floor((Date.now() / 1000 - p.created_at) / 86400) + 1);
      let sub, chip;
      if (p.status === "qualified") { sub = R("Counts toward your gift card", "Cuenta para tu tarjeta", "已计入礼品卡"); chip = `<span class="ref-chip ok">${esc(R("Counted ✓", "Cuenta ✓", "已计入 ✓"))}</span>`; }
      else if (p.status === "pending") {
        const pct = Math.min(100, Math.round(((Math.min(day, days) / days) * 0.5 + (Math.min(p.active_days, act) / act) * 0.5) * 100));
        sub = R(`Day ${day} of ${days} · active ${Math.min(p.active_days, act)} of ${act} days`, `Día ${day} de ${days} · activo ${Math.min(p.active_days, act)} de ${act} días`, `第 ${day}/${days} 天 · 活跃 ${Math.min(p.active_days, act)}/${act} 天`) + `</small><span class="ref-bar"><i style="width:${pct}%"></i></span><small hidden>`;
        chip = `<span class="ref-chip wait">${esc(R("On the way", "En camino", "进行中"))}</span>`;
      } else { sub = (REF_WHY[p.reason] || REF_WHY.inactive)(); chip = `<span class="ref-chip no">${esc(R("Not counted", "No cuenta", "未计入"))}</span>`; }
      const safeSub = p.status === "pending" ? sub.replace(/^[^<]*/, (t) => esc(t)) : esc(sub);
      return `<li><span class="face">${esc((nm[0] || "?").toUpperCase())}</span><span class="nm"><b>${esc(nm)}</b><small>${safeSub}</small></span>${chip}</li>`;
    }).join("");
    const rw = full ? full.rewards : [];
    $("refRewardsCard").hidden = !rw.length;
    $("refCardsT").textContent = R("Your gift cards", "Tus tarjetas de regalo", "你的礼品卡");
    $("refRewards").innerHTML = rw.map((w) => `<li><span class="face">🎁</span><span class="nm"><b>${esc(fmt(w.amount_cents / 100))} ${esc(R("gift card", "tarjeta de regalo", "礼品卡"))}</b><small>${esc(new Date((w.sent_at || w.created_at) * 1000).toLocaleDateString(LOCALE))}</small></span><span class="ref-chip ${w.status === "sent" ? "ok" : "wait"}">${esc(w.status === "sent" ? R("Sent 💌", "Enviada 💌", "已发送 💌") : R("On its way", "En camino", "发送中"))}</span></li>`).join("");
    $("refFine").innerHTML = esc(R(`Friends must be new to Honeybun, confirm their email, and sign up on their own phone or computer. People in your own budget and accounts made on your devices don't count. Gift cards are sent by email within about 5 business days.`,
      `Tus amigos deben ser nuevos en Honeybun, confirmar su correo y registrarse en su propio teléfono o computadora. Las personas de tu propio presupuesto y las cuentas creadas en tus dispositivos no cuentan. Las tarjetas se envían por correo en unos 5 días hábiles.`,
      `好友必须是 Honeybun 新用户、确认邮箱，并在自己的手机或电脑上注册。你自己预算中的成员以及在你设备上创建的账户不计入。礼品卡约在 5 个工作日内通过邮件发送。`)) + ` <a href="/terms.html#referrals">${esc(R("Full rules", "Reglas completas", "完整规则"))}</a>`;
  }
  function refReport(d) {
    const p = d.people || [], amt = refAmt(d);
    if (!p.length) return R(`No one has signed up with your link yet. Share it and I'll tell you the moment someone joins! Every ${d.goal} friends who stick around = a ${amt} gift card 🎁`,
      `Nadie se ha registrado con tu enlace todavía. ¡Compártelo y te aviso en cuanto alguien se una! Cada ${d.goal} amigos = una tarjeta de ${amt} 🎁`,
      `还没有人通过你的链接注册。分享出去，有人加入我会第一时间告诉你！每 ${d.goal} 位好友 = ${amt} 礼品卡 🎁`);
    const wait = p.filter((x) => x.status === "pending").map((x) => x.name).filter(Boolean), got = refInCycle(d);
    let t = R(`${p.length} ${p.length === 1 ? "person has" : "people have"} signed up with your link 🎉 ${d.qualified} counted, ${d.pending} still in their first week${d.rejected ? `, and ${d.rejected} didn't count` : ""}.`,
      `${p.length} ${p.length === 1 ? "persona se registró" : "personas se registraron"} con tu enlace 🎉 ${d.qualified} cuentan, ${d.pending} en su primera semana${d.rejected ? ` y ${d.rejected} no contaron` : ""}.`,
      `已有 ${p.length} 人通过你的链接注册 🎉 已计入 ${d.qualified} 人，${d.pending} 人还在第一周${d.rejected ? `，${d.rejected} 人未计入` : ""}。`);
    if (wait.length) t += " " + R(`Still hopping through week one: ${wait.slice(0, 5).join(", ")}.`, `Aún en su primera semana: ${wait.slice(0, 5).join(", ")}.`, `第一周进行中：${wait.slice(0, 5).join("、")}。`);
    t += " " + R(`You're ${got} of ${d.goal} toward your next ${amt} gift card 🥕`, `Llevas ${got} de ${d.goal} para tu próxima tarjeta de ${amt} 🥕`, `距离下一张 ${amt} 礼品卡：${got}/${d.goal} 🥕`);
    const sent = (d.rewards || []).filter((w) => w.status === "sent").length, pend = (d.rewards || []).length - sent;
    if (pend) t += " " + R(`Your gift card is on its way 💌`, `Tu tarjeta va en camino 💌`, `你的礼品卡正在路上 💌`);
    return t;
  }
  async function askBunRefs() {
    if (screen !== "inbox") await openInbox();
    const box = $("chat");
    const bubble = (cls, html) => { const el = document.createElement("div"); el.className = "msg first pop " + cls; el.innerHTML = `<div class="av"><img src="/icon-192.png" alt=""></div><div class="b">${html}</div>`; box.appendChild(el); chatToEnd(); return el; };
    const q = bubble("me", "<p></p>"); q.querySelector("p").textContent = R("How are my referrals doing?", "¿Cómo van mis referidos?", "我的邀请进展如何？");
    const ty = bubble("typing", "<i></i><i></i><i></i>");
    try {
      const [d] = await Promise.all([api("/api/referrals"), new Promise((r) => setTimeout(r, 800))]);
      REF_FULL = d; ME.ref = { code: d.code, goal: d.goal, reward_cents: d.reward_cents, qualified: d.qualified, pending: d.pending, rejected: d.rejected };
      ty.remove();
      const a = bubble("", `<p></p><div class="acts"></div>`);
      a.querySelector("p").textContent = refReport(d);
      const acts = a.querySelector(".acts");
      const b1 = document.createElement("button"); b1.className = "mini"; b1.textContent = R("See details", "Ver detalles", "查看详情"); b1.onclick = () => show("refer"); acts.appendChild(b1);
      const b2 = document.createElement("button"); b2.className = "mini"; b2.textContent = R("Copy my link", "Copiar mi enlace", "复制链接"); b2.onclick = () => copyRef(); acts.appendChild(b2);
    } catch (e) { ty.remove(); bubble("", "<p></p>").querySelector("p").textContent = e.message; }
  }
  async function copyRef() {
    const r = ME && ME.ref; if (!r) return;
    try { await navigator.clipboard.writeText(refLink(r)); toast(R("Link copied 🎁", "Enlace copiado 🎁", "链接已复制 🎁")); }
    catch { toast(R("Couldn't copy. Press and hold the link instead.", "No se pudo copiar. Mantén presionado el enlace.", "无法复制，请长按链接。")); }
  }
  const refShareText = () => R("I use Honeybun to budget, it's free and super cute 🐰 Try it with my link:", "Uso Honeybun para mi presupuesto, es gratis y muy lindo 🐰 Pruébalo con mi enlace:", "我在用 Honeybun 记账，免费又可爱 🐰 用我的链接试试：");
  $("refCopy").onclick = copyRef;
  $("refShare").onclick = async () => { try { await navigator.share({ title: "Honeybun", text: refShareText(), url: refLink(ME.ref) }); } catch {} };
  $("refText").onclick = () => { location.href = `sms:?&body=${encodeURIComponent(refShareText() + " " + refLink(ME.ref))}`; };
  $("refAsk").onclick = askBunRefs;
  $("qrRefer").onclick = askBunRefs;
  $("openRefer").onclick = () => show("refer");
  // What's new: the same changelog as the landing page, with a badge until you've seen the newest release
  const updLatest = () => { const u = window.HB_UPDATES; return u && u.log[0] ? u.log[0].v : null; };
  function updBadges() {
    const u = window.HB_UPDATES, v = updLatest(), unseen = v && store.get("hb-upd-seen") !== v;
    $("updBadge").hidden = !unseen; if (unseen) $("updBadge").textContent = u.log[0].items.length;
    $("updDot").hidden = !unseen;
  }
  function openUpdates() {
    const u = window.HB_UPDATES;
    if (u && !$("updList").childElementCount) u.render($("updList"), $("updLegend"));
    if (updLatest()) store.set("hb-upd-seen", updLatest());
    updBadges();
  }
  $("sideUpd").onclick = () => show("updates");
  // Windows app: a red dot on the taskbar icon while Bun has unread messages or there's something new
  // in What's new (the app also flashes its taskbar button when the count goes up). Websites get nothing here.
  const tauriInvoke = () => window.__TAURI_INTERNALS__ && window.__TAURI_INTERNALS__.invoke;
  let lastBadge = -1;
  function syncTaskbar() {
    const inv = tauriInvoke(); if (!inv || !ME) return;
    const count = (INBOX.unread || 0) + (updLatest() && store.get("hb-upd-seen") !== updLatest() ? 1 : 0);
    if (count === lastBadge) return;
    lastBadge = count;
    inv("set_unread", { count }).catch(() => {});
  }
  // Windows app: "Check for updates" in the side menu. The app downloads and installs a newer version by itself.
  (() => {
    const btn = $("sideCheckUpd"), label = $("sideCheckUpdT");
    if (!btn || !IS_DESKTOP_APP || !tauriInvoke()) return;
    btn.hidden = false;
    const base = label.textContent;
    let busy = false, timer = 0;
    window.hbUpdateStatus = (state, text, pct) => {
      clearTimeout(timer);
      label.textContent = tr(text) + (pct != null && state === "downloading" ? " " + pct + "%" : "");
      if (state === "current" || state === "error") { busy = false; timer = setTimeout(() => { label.textContent = tr(base); }, 4000); }
    };
    btn.onclick = () => {
      if (busy) return;
      busy = true; label.textContent = tr("Checking for updates…");
      tauriInvoke()("check_for_update").catch(() => window.hbUpdateStatus("error", "Couldn't check right now"));
    };
  })();
  // while minimized the page skips its usual refresh, so check just the unread count once a minute
  if (IS_DESKTOP_APP) setInterval(async () => {
    if (!ME || !(document.hidden || window.hbNativeHidden) || !tauriInvoke()) return;
    try { const r = await api("/api/inbox/count"); INBOX.unread = r.unread; syncTaskbar(); } catch {}
  }, 60000);
  // Get the app: Windows download, browser install, phone steps. Hidden inside the Windows app and installed apps.
  const installedApp = IS_DESKTOP_APP || IOS_NATIVE || matchMedia("(display-mode: standalone)").matches;
  $("sideGet").hidden = installedApp; $("openGet").hidden = installedApp;
  const openGet = () => {
    const ua = navigator.userAgent, mobile = /iPhone|iPad|iPod|Android/.test(ua);
    $("getWinOpt").hidden = mobile || /Mac OS X/.test(ua) && !/Windows/.test(ua);
    $("getDlg").showModal();
  };
  $("sideGet").onclick = openGet; $("openGet").onclick = openGet;
  $("getClose").onclick = () => $("getDlg").close();
  $("openUpd").onclick = () => show("updates");
  window.addEventListener("load", updBadges);
  $("sideRefer").onclick = () => show("refer");

  // ---------- Bun's tip of the day (home) ----------
  // Personal tips come from this month's real numbers; general tips fill in. The tip changes each day,
  // and "Another tip" flips through the rest.
  let tipIdx = null, tipKey = "";
  const whole = (n) => fmt(n).replace(/\.00$/, "");
  const GENERAL_TIPS = [
    ["Try a no-spend day this week. Paw prints on your hop calendar mark each one 🐾", "Intenta un día sin gastos esta semana. Las huellas en tu calendario marcan cada uno 🐾", "这周试试零花费的一天吧。蹦跳日历上的爪印会标记每一天 🐾"],
    ["Wait a day before buying anything over $50. If you still want it tomorrow, go for it 🐰", "Espera un día antes de comprar algo de más de $50. Si mañana aún lo quieres, adelante 🐰", "超过 $50 的东西先等一天再买。明天还想要，就买吧 🐰"],
    ["Set a budget for your biggest category. I'll give you a heads-up at 80% 🥕", "Pon un presupuesto a tu categoría más grande. Te aviso al llegar al 80% 🥕", "给花得最多的类别设个预算。到 80% 时我会提醒你 🥕"],
    ["Give your savings goal a fun name. People save more for a \"Beach trip\" than for \"Savings\" 🍯", "Ponle un nombre divertido a tu meta. Se ahorra más para un \"Viaje a la playa\" que para \"Ahorros\" 🍯", "给储蓄目标起个有趣的名字。人们为“海边旅行”存的钱比为“储蓄”多 🍯"],
    ["Planning meals on Sunday is one of the easiest ways to spend less on food 🥕", "Planear las comidas el domingo es una de las formas más fáciles de gastar menos en comida 🥕", "周日提前规划一周饮食，是减少餐饮开销最简单的方法之一 🥕"],
    ["Add your bills once in Plan, and I'll remind you before each one is due 🐰", "Agrega tus facturas una vez en Plan y te recordaré antes de cada vencimiento 🐰", "在计划里添加一次账单，每次到期前我都会提醒你 🐰"],
    ["Check Together once a week, so nobody's surprised by who owes who 💞", "Revisa Juntos una vez por semana para que nadie se sorprenda con quién le debe a quién 💞", "每周看一次“一起”，谁欠谁就不会有惊喜了 💞"],
    ["Mark personal spending as private. Only you will see it 🔒", "Marca tus gastos personales como privados. Solo tú los verás 🔒", "把个人开销设为私密，只有你能看到 🔒"],
    ["Paying yourself first works: move a little into a honey jar right after payday 🍯", "Págate primero: pasa un poco a un frasco de miel justo después del día de pago 🍯", "先存后花很有效：发薪后马上往蜂蜜罐里存一点 🍯"],
    ["Small daily treats add up. $5 a day is about $150 a month ☕", "Los pequeños gustos diarios suman. $5 al día son unos $150 al mes ☕", "每天的小犒劳会积少成多。每天 $5 大约就是每月 $150 ☕"],
  ];
  function personalTips() {
    const out = [], t = today(), now = MONTH === t.slice(0, 7);
    const exp = ENTRIES.filter((e) => e.type === "expense" && !e.pending);
    const by = spentByCat();
    const [y, mo] = MONTH.split("-").map(Number), dim = new Date(y, mo, 0).getDate();
    const daysLeft = now ? dim - +t.slice(8) + 1 : 0;
    // a budget running low (or over)
    const buds = Object.entries(BUDGETS).map(([c, lim]) => ({ c, lim, sp: by[c] || 0 })).filter((b) => b.lim > 0);
    const over = buds.filter((b) => b.sp > b.lim).sort((a, b) => b.sp - b.lim - (a.sp - a.lim))[0];
    if (over) { const n = tr(catOf(over.c).n); out.push(R(`${n} is ${whole(over.sp - over.lim)} over budget. No stress, next month is a fresh start. Maybe set it a little higher? 🐰`, `${n} se pasó por ${whole(over.sp - over.lim)}. Tranquilo, el próximo mes empieza de cero. ¿Quizá subirlo un poco? 🐰`, `${n} 超出预算 ${whole(over.sp - over.lim)}。别担心，下个月重新开始。要不要稍微调高一点？🐰`)); }
    const low = buds.filter((b) => b.sp < b.lim && b.sp >= b.lim * 0.6).sort((a, b) => b.sp / b.lim - a.sp / a.lim)[0];
    if (low && daysLeft > 1) { const n = tr(catOf(low.c).n), left = low.lim - low.sp, per = left / daysLeft; out.push(R(`${n} has ${whole(left)} left for ${daysLeft} more days. That's about ${fmt(per)} a day 🥕`, `A ${n} le quedan ${whole(left)} para ${daysLeft} días más. Son unos ${fmt(per)} al día 🥕`, `${n} 还剩 ${whole(left)}，还有 ${daysLeft} 天，每天大约 ${fmt(per)} 🥕`)); }
    // a habit that adds up
    const cnt = {}; exp.forEach((e) => { if (WANTS.includes(e.category) && e.category !== "other" && e.category !== "subs") { cnt[e.category] = cnt[e.category] || { n: 0, sum: 0 }; cnt[e.category].n++; cnt[e.category].sum += e.amount; } });
    const habit = Object.entries(cnt).filter(([, v]) => v.n >= 4).sort((a, b) => b[1].sum - a[1].sum)[0];
    if (habit) { const [c, v] = habit, n = tr(catOf(c).n), save = (v.sum / v.n) * 2; out.push(R(`You've logged ${n.toLowerCase()} ${v.n} times this month (${whole(v.sum)}). Skipping two could save about ${whole(Math.round(save))} 🐰`, `Registraste ${n.toLowerCase()} ${v.n} veces este mes (${whole(v.sum)}). Saltarte dos podría ahorrarte unos ${whole(Math.round(save))} 🐰`, `这个月你记了 ${v.n} 次${n}（${whole(v.sum)}）。少两次大约能省 ${whole(Math.round(save))} 🐰`)); }
    // subscriptions
    const perMonth = { weekly: 52 / 12, biweekly: 26 / 12, monthly: 1 };
    const subs = RECUR.filter((r) => r.type === "expense" && r.category === "subs");
    if (subs.length) { const tot = subs.reduce((a, r) => a + (r.amount_cents / 100) * (perMonth[r.freq] || 1), 0); out.push(R(`You pay about ${whole(Math.round(tot))} a month for ${subs.length} subscription${subs.length > 1 ? "s" : ""}. Any you've stopped using? 📺`, `Pagas unos ${whole(Math.round(tot))} al mes en ${subs.length} suscripción${subs.length > 1 ? "es" : ""}. ¿Alguna que ya no uses? 📺`, `你每月大约为 ${subs.length} 个订阅支付 ${whole(Math.round(tot))}。有没有已经不用的？📺`)); }
    // no-spend days this week
    if (now) {
      const td = parseD(t), mon = addDays(td, -((td.getDay() + 6) % 7)), spentDays = new Set(exp.map((e) => e.date));
      let free = 0; for (let d = new Date(mon); toS(d) < t; d = addDays(d, 1)) if (!spentDays.has(toS(d))) free++;
      if (free >= 1) out.push(R(`${free} no-spend day${free > 1 ? "s" : ""} this week so far 🐾 One more would be amazing!`, `Llevas ${free} día${free > 1 ? "s" : ""} sin gastos esta semana 🐾 ¡Uno más sería genial!`, `这周已经有 ${free} 天零花费 🐾 再来一天就太棒了！`));
    }
    // a savings goal
    const g = GOALS.filter((x) => x.saved_cents < x.target_cents).sort((a, b) => a.saved_cents / a.target_cents - b.saved_cents / b.target_cents)[0];
    if (g) { const left = (g.target_cents - g.saved_cents) / 100, wk = Math.max(5, Math.ceil(left / 13 / 5) * 5); out.push(R(`Putting ${whole(wk)} a week into "${g.name}" fills it in about ${Math.ceil(left / wk)} weeks 🍯`, `Poniendo ${whole(wk)} por semana en "${g.name}" lo llenas en unas ${Math.ceil(left / wk)} semanas 🍯`, `每周往“${g.name}”存 ${whole(wk)}，大约 ${Math.ceil(left / wk)} 周就能存满 🍯`)); }
    // streak
    const st = streakOf(meMember());
    if (now && st >= 2 && !loggedToday()) out.push(R(`Log one thing today to keep your ${st}-day streak hopping 🐾`, `Registra algo hoy para mantener tu racha de ${st} días 🐾`, `今天记一笔，保持你 ${st} 天的连续记录 🐾`));
    return out;
  }
  function renderTip(step) {
    const box = $("bunTip"); if (!box) return;
    const tips = personalTips().concat(GENERAL_TIPS.map((x) => R(x[0], x[1], x[2])));
    const key = today() + "|" + tips.length;
    if (tipIdx === null || key !== tipKey) {
      tipKey = key;
      const day = Math.floor(parseD(today()).getTime() / 86400000);
      const nPersonal = tips.length - GENERAL_TIPS.length;
      tipIdx = nPersonal ? day % nPersonal : day % tips.length; // lead with a personal tip when there is one
    }
    if (step) tipIdx = (tipIdx + 1) % tips.length;
    box.hidden = false;
    $("bunTipH").textContent = R("Bun's tip", "Consejo de Bun", "Bun 的小贴士");
    $("bunTipNext").textContent = R("Another tip ›", "Otro consejo ›", "换一条 ›");
    const p = $("bunTipText"), text = tips[tipIdx];
    if (!step) { p.textContent = text; return; }
    p.classList.add("swap");
    setTimeout(() => { p.textContent = text; p.classList.remove("swap"); }, 200);
  }
  $("bunTipNext").onclick = () => renderTip(true);


  // ---------- Bun's moods and heads-up alerts (Home) ----------
  function renderBunExtras() {
    const t = today(), m = meMember() || {};
    // mood: after 3 quiet days Bun gets sleepy and asks you to log something; logging brings the tip card back
    const gap = m.last_day ? Math.round((parseD(t) - parseD(m.last_day)) / 86400000) : 0;
    const sleepy = MONTH === t.slice(0, 7) && gap >= 3;
    const mood = $("bunMood"); mood.hidden = !sleepy;
    if (sleepy) {
      $("bunMoodH").textContent = tr("Bun is a little sleepy…");
      $("bunMoodP").textContent = tr("No spending logged in") + " " + gap + " " + tr("days. Add what you spent and Bun perks right up.");
      $("bunMoodBtn").textContent = tr("Log something");
      $("bunMoodBtn").onclick = () => openAdd();
      $("bunTip").hidden = true;
    }
    // alerts: budgets close to or over their limit, and subscription price changes from the last month
    const box = $("bunAlerts"), rows = [], by = spentByCat();
    const [y, mo] = MONTH.split("-").map(Number), dim = new Date(y, mo, 0).getDate(), daysLeft = MONTH === t.slice(0, 7) ? dim - +t.slice(8) + 1 : 0;
    Object.entries(BUDGETS).map(([c, lim]) => ({ c, lim, sp: by[c] || 0 })).filter((x) => x.lim > 0 && x.sp >= x.lim * 0.8)
      .sort((a, b) => b.sp / b.lim - a.sp / a.lim).slice(0, 2).forEach((x) => {
        const pct = Math.round((x.sp / x.lim) * 100), name = tr(catOf(x.c).n);
        const over = x.sp > x.lim;
        const note = over ? `${whole(x.sp - x.lim)} ${tr("over")} · ${whole(x.sp)} ${tr("of")} ${whole(x.lim)}` : `${whole(x.sp)} ${tr("of")} ${whole(x.lim)}${daysLeft > 1 ? " · " + fmt((x.lim - x.sp) / daysLeft) + " " + tr("a day left") : ""}`;
        rows.push(`<div class="ba-row warn"><span class="ba-ic">${esc(catOf(x.c).e || "📊")}</span><div class="ba-t">${esc(name)}: ${over ? esc(tr("over budget")) : pct + "% " + esc(tr("of your budget used"))}<small>${esc(note)}</small><div class="ba-bar"><i style="width:${Math.min(100, pct)}%"></i></div></div></div>`);
      });
    const seen = (() => { try { return JSON.parse(store.get("hb-price-seen") || "[]"); } catch { return []; } })();
    RECUR.filter((r) => r.type === "expense" && r.prev_amount_cents && r.price_changed_at && !seen.includes(r.id + "|" + r.amount_cents)
      && (parseD(t) - parseD(r.price_changed_at)) / 86400000 <= 30).slice(0, 2).forEach((r) => {
        const up = r.amount_cents > r.prev_amount_cents;
        rows.push(`<div class="ba-row"><span class="ba-ic">${up ? "📈" : "📉"}</span><div class="ba-t">${esc(r.label)} ${esc(tr(up ? "is now" : "dropped to"))} ${fmt(r.amount_cents / 100)}<small>${esc(tr("It was"))} ${fmt(r.prev_amount_cents / 100)}</small></div><button class="ba-x" type="button" data-seen="${esc(r.id + "|" + r.amount_cents)}" aria-label="${esc(tr("Dismiss"))}">×</button></div>`);
      });
    box.hidden = !rows.length;
    if (rows.length) {
      box.innerHTML = `<b class="ba-h">${esc(tr("Heads up from Bun"))}</b>` + rows.join("");
      box.querySelectorAll("[data-seen]").forEach((b) => (b.onclick = () => { seen.push(b.dataset.seen); store.set("hb-price-seen", JSON.stringify(seen.slice(-40))); renderBunExtras(); fitDesktop(); }));
    }
  }

  // ---------- help ----------
  const HELP = [
    { t: "Getting started", d: "Budgets, bills, goals and household setup", q: [
      ["How do I invite my partner or family?", "Go to Together and share your invite link or code. When they sign up with it, you'll share one budget."],
      ["How do referral gift cards work?", "Open Invite friends from Home or Settings and share your link. A friend counts once they confirm their email, log spending on 4 different days, and are still using Honeybun a week after signing up. Every 10 friends who count earns you a $10 gift card by email. Ask Bun in your inbox anytime to see who signed up."],
      ["How do bills and paydays work?", "Add them once in Plan, or tap + and choose how often it repeats. Home shows what's due before your next payday, and Bun reminds you."],
      ["How do monthly budgets work?", "In Plan, tap Edit next to Budget and set a limit for any category. Bun gives you a heads-up at 80%."]] },
    { t: "Adding transactions", d: "Spending, income, splits and repeats", q: [
      ["What are the one-tap buttons on the Add screen?", "Your five most common expenses from the last 90 days. Tap one and it's logged right away with the same amount, category and split as last time. You can edit it after like any entry."],
      ["Can Apple Pay log purchases automatically?", "Yes. In Settings, open Apple Pay auto-logging and make a key. Then an iPhone Shortcut automation runs every time you tap to pay and sends the amount and store to Honeybun. It picks the category from the store name and remembers how you split each store. No bank connection needed."],
      ["How do I split an expense?", "When adding an expense, tap Split it, then choose Evenly, By %, or Set amount owed."],
      ["Can I keep something private?", "Yes. For your own personal spending or income, turn on Only I can see this."],
      ["How do I edit or delete something?", "Tap any entry to edit it. Tap × to delete it, and you can Undo right after."]] },
    { t: "Together", d: "Shared expenses, balances and settling up", q: [
      ["How does Settle up work?", "Honeybun adds up every split expense. When one of you pays the other back, tap Settle up so the balance resets."],
      ["Can I use Honeybun on my own?", "Yes. Pick Just me when you start, or change the budget type anytime in Settings."]] },
    { t: "Stats & exports", d: "Monthly insights, badges and CSV exports", q: [
      ["How do carrots and streaks work?", "You earn carrots when you log spending, pay bills, save, or settle up. Log one thing each day to keep your hop streak and level up your bunny."],
      ["Can I export my data?", "Yes. In Settings, under Data, you can download a spreadsheet (CSV) or a full copy of your data."]] },
  ];
  let helpTopic = null;
  function renderHelp() {
    const q = ($("helpQ").value || "").trim().toLowerCase();
    const tb = $("helpTopics"); tb.innerHTML = "";
    HELP.forEach((h, i) => {
      const b = document.createElement("button"); b.className = "help-card"; b.setAttribute("aria-pressed", helpTopic === i ? "true" : "false");
      b.innerHTML = `<b>${esc(tr(h.t))}</b><small>${esc(tr(h.d))}</small>`;
      b.onclick = () => { helpTopic = helpTopic === i ? null : i; renderHelp(); };
      tb.appendChild(b);
    });
    const list = $("faq"); list.innerHTML = "";
    HELP.forEach((h, i) => {
      if (helpTopic !== null && helpTopic !== i) return;
      h.q.forEach(([qq, a]) => {
        const Q = tr(qq), A = tr(a);
        if (q && !(Q + " " + A).toLowerCase().includes(q)) return;
        const d = document.createElement("details");
        d.innerHTML = "<summary></summary><p></p>"; d.querySelector("summary").textContent = Q; d.querySelector("p").textContent = A;
        list.appendChild(d);
      });
    });
    if (!list.children.length) list.innerHTML = `<div class="none">${esc(tr("No answers match that. Email us and we'll help."))}</div>`;
    const bug = `mailto:help@honeybun.me?subject=${encodeURIComponent(tr("Honeybun problem report"))}&body=${encodeURIComponent(tr("What happened, and what did you expect?") + "\n\n")}`;
    $("helpBug").href = bug; $("helpMail").href = $("mailHelp").href;
  }
  $("helpQ").oninput = renderHelp;

  // ---------- search & filters ----------
  const searching = () => !!($("q").value.trim() || $("fType").value || $("fCat").value || $("fWho").value || $("fMin").value || $("fMax").value || $("fFrom").value || $("fTo").value);
  $("fMore").onclick = () => { const open = $("fMoreBox").hidden; $("fMoreBox").hidden = !open; $("fMore").setAttribute("aria-expanded", String(open)); };
  function drawFilters() {
    const fc = $("fCat");
    if (fc.options.length !== CATS.length + 1) CATS.forEach((c) => fc.add(new Option(tr(c.n), c.id)));
    const fw = $("fWho"), cur = fw.value;
    while (fw.options.length > 1) fw.remove(1);
    MEMBERS.forEach((m) => fw.add(new Option(`${m.emoji} ${m.name}`, m.id)));
    fw.value = cur; fw.hidden = MEMBERS.length < 2;
  }
  // "Everything this month" and search results: 8 per page with page buttons underneath
  const PAGE_SIZE = 8;
  let listPage = 0, listKey = "", pageSize = PAGE_SIZE, listRows = null;
  function drawPaged(rows, key) {
    if (key !== listKey) { listKey = key; listPage = 0; }
    listRows = rows;
    const pages = Math.ceil(rows.length / pageSize);
    listPage = Math.min(listPage, pages - 1);
    const l = $("list"); l.innerHTML = "";
    rows.slice(listPage * pageSize, (listPage + 1) * pageSize).forEach((e) => l.appendChild(entryLi(e)));
    const pg = $("listPager");
    pg.hidden = pages < 2;
    if (pages < 2) return;
    const go = (i) => { listPage = i; drawPaged(rows, key); $("allH").scrollIntoView({ behavior: "smooth", block: "start" }); };
    // page numbers: first, last, and the ones around the current page
    const nums = [];
    for (let i = 0; i < pages; i++) if (i === 0 || i === pages - 1 || Math.abs(i - listPage) <= 1) nums.push(i); else if (nums[nums.length - 1] !== "…") nums.push("…");
    pg.innerHTML = "";
    const btn = (label, i, cls, aria) => {
      const b = document.createElement("button"); b.type = "button"; b.className = cls; b.textContent = label;
      if (aria) b.setAttribute("aria-label", aria);
      if (i === null) b.disabled = true; else b.onclick = () => go(i);
      pg.appendChild(b);
    };
    btn("‹", listPage > 0 ? listPage - 1 : null, "pg-arrow", tr("Previous page"));
    nums.forEach((n) => n === "…" ? pg.insertAdjacentHTML("beforeend", '<span class="pg-gap">…</span>') : btn(String(n + 1), n === listPage ? null : n, "pg-num" + (n === listPage ? " on" : ""), null));
    btn("›", listPage < pages - 1 ? listPage + 1 : null, "pg-arrow", tr("Next page"));
    const from = listPage * pageSize + 1, to = Math.min(rows.length, (listPage + 1) * pageSize);
    pg.insertAdjacentHTML("beforeend", `<span class="pg-info">${esc(tr(`${from}–${to} of ${rows.length}`))}</span>`);
  }
  let searchTimer;
  async function runSearch() {
    if (!searching()) { $("searchHint").hidden = true; render(); return; }
    const params = new URLSearchParams({ q: $("q").value.trim(), type: $("fType").value, cat: $("fCat").value, member: $("fWho").value,
      min: $("fMin").value, max: $("fMax").value, from: $("fFrom").value, to: $("fTo").value });
    try {
      const d = await api("/api/search?" + params);
      const rows = d.entries.map((e) => ({ ...e, amount: e.amount_cents / 100, shared: !!e.shared, private: !!e.private }));
      $("allTitle").textContent = "Search results";
      const total = rows.reduce((s, e) => s + (e.type === "income" ? e.amount : -e.amount), 0);
      $("searchHint").hidden = false;
      $("searchHint").textContent = rows.length ? `${rows.length} found · net ${fmt(total)}` : "Nothing matches that.";
      if (rows.length) drawPaged(rows, "s:" + params); else { $("list").innerHTML = ""; $("listPager").hidden = true; }
    } catch (e) { toast(e.message); }
  }
  $("q").oninput = () => { clearTimeout(searchTimer); searchTimer = setTimeout(runSearch, 300); };
  ["fType", "fCat", "fWho", "fFrom", "fTo"].forEach((id) => ($(id).onchange = runSearch));
  ["fMin", "fMax"].forEach((id) => ($(id).oninput = () => { clearTimeout(searchTimer); searchTimer = setTimeout(runSearch, 300); }));

  // ---------- email, account & data ----------
  $("hideVerify").onclick = () => { store.set("hb-verify-hide", String(Date.now() + 3 * 86400000)); $("verifyBanner").hidden = true; };
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
      try { Object.keys(localStorage).filter((k) => k.startsWith("hb-") && k !== "hb-device" && k !== "hb-desktop" && k !== "hb-halloween").forEach((k) => localStorage.removeItem(k)); } catch {}
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
      if (e.status === 401) {
        if (!pendingCode && !store.get("hb-had-account") && !IS_DESKTOP_APP) { show("landing"); return; }
        authMode = pendingCode ? "signup" : store.get("hb-had-account") ? "login" : "signup"; showAuth();
      }
      else { showAuth(); $("authErr").textContent = e.message; }
    }
  })();
})();
