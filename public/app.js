(() => {
  "use strict";

  // ---------- constants ----------
  const CATS = [
    { id: "home", e: "🏠", n: "Home", c: "#9BB8FF" },
    { id: "groc", e: "🛒", n: "Groceries", c: "#46BE8A" },
    { id: "food", e: "🍜", n: "Eating out", c: "#FF9F5A" },
    { id: "date", e: "💕", n: "Date night", c: "#FF6F9F" },
    { id: "bills", e: "💡", n: "Bills", c: "#FFC94D" },
    { id: "car", e: "🚗", n: "Getting around", c: "#5CC6D0" },
    { id: "fun", e: "🎁", n: "Gifts & fun", c: "#B79CFF" },
    { id: "pets", e: "🐾", n: "Kids & pets", c: "#D9A27A" },
    { id: "other", e: "✨", n: "Other", c: "#B7A9C4" },
  ];
  const EMOJIS = ["🐰", "🐻", "🐱", "🐶", "🦊", "🐼", "🐨", "🐸", "🐧", "🦄", "🐥", "🐹"];
  const COLORS = ["#FFD6E5", "#FFF0C2", "#DDF5E9", "#E4EDFF", "#EADFFF", "#FFE1CC"];
  const THEMES = [
    { id: "blueberry", n: "Blueberry", c: "#6F93DB" },
    { id: "blush", n: "Blush", c: "#EE7FA3" },
    { id: "lavender", n: "Lavender", c: "#9C82DC" },
    { id: "honey", n: "Honey", c: "#DDA13F" },
  ];
  const FREQ_NAME = { weekly: "Every week", biweekly: "Every 2 weeks", monthly: "Every month" };

  // ---------- helpers ----------
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const fmt = (n) => (n < 0 ? "−" : "") + "$" + Math.abs(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const pad = (n) => String(n).padStart(2, "0");
  const toS = (d) => d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  const parseD = (s) => { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); };
  const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  const today = () => toS(new Date());
  const ym = (d) => d.slice(0, 7);
  const dayName = (d) => d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
  const shortDay = (d) => d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  };
  function monthName(m, short) {
    const [y, mo] = m.split("-").map(Number);
    return new Date(y, mo - 1, 1).toLocaleDateString(undefined, short ? { month: "short", year: "2-digit" } : { month: "long", year: "numeric" });
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
    if (method !== "GET") { opts.headers["content-type"] = "application/json"; opts.body = JSON.stringify(body ?? {}); }
    let res;
    try { res = await fetch(path, opts); } catch { throw new Error("You're offline. Check your connection and try again."); }
    let data = {};
    try { data = await res.json(); } catch {}
    if (!res.ok) {
      const e = new Error(data.error || "Something went wrong. Try again.");
      e.status = res.status;
      if (res.status === 401 && !["/api/login", "/api/me"].includes(path)) { ME = null; showAuth(); }
      throw e;
    }
    return data;
  }

  // ---------- state ----------
  let ME = null, NEST = null, MEMBERS = [], ENTRIES = [], BAL = {}, SETTLES = [], RECUR = [], LOGGED = new Set(), JAR = [];
  let MONTH = today().slice(0, 7);
  let screen = "loading", filter = null, authMode = "signup";
  // add/edit form
  let mode = "expense", cat = "groc", who = null, shared = true, splitMode = "equal", editing = null;
  let pendingCode = null, resetToken = null;
  {
    const j = location.pathname.match(/^\/join\/([A-Za-z0-9-]{4,20})\/?$/);
    if (j) pendingCode = j[1];
    const r = location.pathname.match(/^\/reset\/([A-Za-z0-9_-]{20,100})\/?$/);
    if (r) resetToken = r[1];
  }
  const member = (id) => MEMBERS.find((m) => m.id === id) || { name: "Someone", emoji: "❔", color: "#EEE" };
  const meMember = () => MEMBERS.find((m) => m.id === ME?.id);
  const others = (id) => MEMBERS.filter((m) => m.id !== id);

  // ---------- screens ----------
  const APP_SCREENS = ["home", "add", "us"];
  function show(s) {
    screen = s;
    ["loading", "auth", "reset", "setup", "home", "add", "us"].forEach((k) => ($("scr-" + k).hidden = k !== s));
    const inApp = APP_SCREENS.includes(s);
    $("nav").hidden = !inApp; $("topBar").hidden = !inApp;
    document.querySelectorAll("nav.bottom [data-go]").forEach((b) => b.dataset.go === s ? b.setAttribute("aria-current", "page") : b.removeAttribute("aria-current"));
    window.scrollTo(0, 0);
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
      await api(authMode === "signup" ? "/api/signup" : "/api/login", { method: "POST", body: { name, email, password } });
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
    if (pendingCode) {
      try { await api("/api/nests/join", { method: "POST", body: { code: pendingCode } }); toast("You joined the budget"); }
      catch (e) { $("setupErr").textContent = e.message; toast(e.message); }
      pendingCode = null; history.replaceState(null, "", "/");
      return afterAuth();
    }
    if (!me.nest_id) { $("setupHi").textContent = "Hi, " + ME.name + "!"; show("setup"); return; }
    await loadNest();
    show("home"); bunnyHop();
    if (!store.get("hb-tour-" + ME.id)) setTimeout(openTour, 350);
  }
  async function logout() {
    try { await api("/api/logout", { method: "POST" }); } catch {}
    ME = null; NEST = null; MEMBERS = []; ENTRIES = []; filter = null; editing = null;
    authMode = "login"; showAuth();
  }
  $("setupLogout").onclick = logout;
  $("logoutBtn").onclick = logout;

  // ---------- setup ----------
  $("createNest").onclick = async () => {
    busy($("createNest"), true); $("setupErr").textContent = "";
    try { await api("/api/nests", { method: "POST", body: { name: $("newNestName").value } }); await afterAuth(); }
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
    BAL = d.balances; SETTLES = d.settlements; RECUR = d.recurring; JAR = d.jar;
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
      await api(`/api/recurring/${r.id}/log`, { method: "POST", body: { occ_date: toS(d) } });
      await loadNest();
      toast(r.type === "income" ? "Payday logged" : r.label + " marked paid");
      bunnyHop();
    } catch (e) { toast(e.message); if (btn) busy(btn, false); }
  }

  // ---------- rendering ----------
  function setBunny(left, inc, out, any) {
    const r = inc > 0 ? out / inc : out > 0 ? 2 : 0;
    let msg, path = "M53 90 q3.5 4 7 0 q3.5 4 7 0", p = "";
    if (!any) msg = "Add your first paycheck to begin.";
    else if (inc === 0) { msg = "No income logged yet."; path = "M54 91 h12"; }
    else if (r > 1) { msg = "A little over this month."; path = "M53 93 q7 -5 14 0"; }
    else if (r > 0.8) { msg = "Almost at the limit."; path = "M54 91 q6 1.5 12 0"; }
    else {
      msg = Math.round((1 - r) * 100) + "% of this month is still ours.";
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
      private: e.private, date: e.date, recurring_id: e.recurring_id, occ_date: e.occ_date };
  }
  async function deleteEntry(e) {
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

  function render() {
    if (!NEST) return;
    document.documentElement.setAttribute("data-accent", NEST.accent || "blueberry");
    $("monthLbl").textContent = monthName(MONTH, true);
    const names = MEMBERS.map((m) => m.name);
    $("hi").textContent = NEST.name || (MEMBERS.length === 2 ? `${names[0]} & ${names[1]}` : MEMBERS.length === 1 ? names[0] : "Our family");

    const all = ENTRIES, view = filter ? all.filter((e) => e.member_id === filter) : all;
    const sum = (arr, t) => arr.filter((e) => e.type === t).reduce((s, e) => s + e.amount, 0);
    const inc = sum(view, "income"), out = sum(view, "expense"), left = inc - out;

    if (screen === "home") {
      $("leftLbl").textContent = filter ? member(filter).name + "'s balance" : "Left for us this month";
      $("leftAmt").textContent = fmt(left); $("leftAmt").classList.toggle("neg", left < 0);
      $("meter").style.width = inc > 0 ? Math.min(100, (out / inc) * 100) + "%" : out > 0 ? "100%" : "0";
      $("flowIn").textContent = "+" + fmt(inc) + " in"; $("flowOut").textContent = fmt(out) + " out";
      setBunny(left, inc, out, view.length > 0);
      const isThisMonth = MONTH === today().slice(0, 7);
      $("dueCard").hidden = !isThisMonth;
      if (isThisMonth) renderDue(sum(all, "income") - sum(all, "expense"));

      const cp = $("couple"); cp.innerHTML = "";
      const amp = () => { const h = document.createElement("span"); h.className = "heart"; h.textContent = "&"; h.setAttribute("aria-hidden", "true"); return h; };
      MEMBERS.forEach((m, i) => {
        if (i > 0 && MEMBERS.length === 2) cp.appendChild(amp());
        const mi = all.filter((e) => e.member_id === m.id && e.type === "income").reduce((s, e) => s + e.amount, 0);
        const mo = all.filter((e) => e.member_id === m.id && e.type === "expense").reduce((s, e) => s + e.amount, 0);
        const b = document.createElement("button"); b.className = "pal"; b.setAttribute("aria-pressed", filter === m.id ? "true" : "false");
        b.setAttribute("aria-label", `${m.name}: earned ${fmt(mi)}, paid ${fmt(mo)}. Tap to see only theirs.`);
        b.innerHTML = `<span class="face" style="background:${esc(m.color)}">${esc(m.emoji)}</span><span class="nm">${esc(m.name)}</span><span class="st">+${fmt(mi)}<br>−${fmt(mo).replace("−", "")}</span>`;
        b.onclick = () => { filter = filter === m.id ? null : m.id; render(); };
        cp.appendChild(b);
      });
      if (MEMBERS.length === 1) {
        const b = document.createElement("button"); b.className = "pal";
        b.innerHTML = `<span class="face" style="background:var(--card);box-shadow:inset 0 0 0 2px var(--line);color:var(--soft)">＋</span><span class="nm">Invite</span><span class="st">your partner</span>`;
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

    if (screen === "us") {
      // settle up
      const st = $("settle"), ps = pairs();
      if (MEMBERS.length < 2) st.innerHTML = `<p class="empty" style="margin:0">Invite your partner to split costs.</p>`;
      else if (!ps.length) st.innerHTML = `<div class="owe">You're all even ♡</div>`;
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

      // bills & paydays
      const bl = $("bills"); bl.innerHTML = "";
      if (!RECUR.length) bl.innerHTML = `<li class="empty" style="justify-content:center;border:0">Rent, subscriptions, paychecks. Add them once.</li>`;
      RECUR.forEach((r) => {
        const isIn = r.type === "income", c = CATS.find((x) => x.id === r.category) || CATS[4], n = nextOcc(r);
        const li = document.createElement("li"); li.className = "clickable";
        li.innerHTML = `<div class="ic" style="${isIn ? "background:var(--mint-t)" : ""}">${isIn ? "💰" : c.e}</div>
          <div class="mid"><div class="t">${esc(r.label)}</div><div class="s">${FREQ_NAME[r.freq]}${n ? ", next " + shortDay(n) : ""}, ${esc(member(r.member_id).name)}</div></div>
          <div class="amt ${isIn ? "in" : ""}">${isIn ? "+" : ""}${fmt(r.amount_cents / 100)}</div>`;
        li.onclick = () => openEditRecurring(r);
        bl.appendChild(li);
      });

      // jar
      const saved = NEST.goal_saved / 100, target = NEST.goal_target / 100;
      const pct = target > 0 ? Math.min(100, (saved / target) * 100) : 0, h = (80 * pct) / 100;
      $("jarFill").setAttribute("y", 98 - h); $("jarFill").setAttribute("height", h);
      $("goalName").textContent = NEST.goal_name;
      $("goalProg").textContent = fmt(saved) + " of " + fmt(target) + (pct >= 100 ? " · reached ♡" : " · " + Math.round(pct) + "%");
      const jh = $("jarHist"); jh.innerHTML = "";
      JAR.slice(0, 6).forEach((j) => {
        const li = document.createElement("li"), inn = j.amount_cents > 0;
        const when = new Date(j.created_at * 1000).toLocaleDateString(undefined, { month: "short", day: "numeric" });
        li.innerHTML = `<span><b>${esc(member(j.member_id).name)}</b> ${inn ? "added" : "took out"} ${fmt(Math.abs(j.amount_cents) / 100)}, ${when}</span><button aria-label="Remove">✕</button>`;
        li.querySelector("button").onclick = async () => {
          if (!(await ask("Remove this from the history?", "The jar total will be corrected.", "Remove"))) return;
          try { await api("/api/jar/" + j.id, { method: "DELETE" }); await loadNest(); } catch (e) { toast(e.message); }
        };
        jh.appendChild(li);
      });

      // categories
      const bars = $("bars"); bars.innerHTML = ""; const by = {};
      all.filter((e) => e.type === "expense").forEach((e) => (by[e.category] = (by[e.category] || 0) + e.amount));
      const rows = CATS.filter((c) => by[c.id]).sort((a, b) => by[b.id] - by[a.id]); const mx = Math.max(1, ...rows.map((c) => by[c.id]));
      if (!rows.length) bars.innerHTML = `<p class="empty" style="margin:0">No spending yet this month.</p>`;
      rows.forEach((c) => {
        const d = document.createElement("div"); d.className = "bar";
        d.innerHTML = `<div class="l"><span>${c.e} ${c.n}</span><span>${fmt(by[c.id])}</span></div><div class="trk"><i style="width:${(by[c.id] / mx) * 100}%;background:${c.c}"></i></div>`;
        bars.appendChild(d);
      });
      const l = $("list"); l.innerHTML = "";
      if (!all.length) l.innerHTML = `<li class="empty" style="justify-content:center;border:0">Nothing logged for ${esc(monthName(MONTH))}.</li>`;
      all.forEach((e) => l.appendChild(entryLi(e)));

      $("inviteCode").textContent = prettyCode(NEST.invite_code);
      $("inviteLink").textContent = inviteUrl();
      $("shareInvite").hidden = !navigator.share;
      if (document.activeElement !== $("nestName")) $("nestName").value = NEST.name;
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
  function openEditEntry(e) { editing = { kind: "entry", x: e }; fillForm(e, false); show("add"); }
  function openEditRecurring(r) { editing = { kind: "recurring", x: r }; fillForm(r, true); show("add"); }
  $("cancelEdit").onclick = () => { const back = editing?.kind === "recurring" ? "us" : "home"; editing = null; show(back); };
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
    const label = $("lbl").value.trim() || (mode === "income" ? "Paycheck" : CATS.find((c) => c.id === cat).n);
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
        editing = null; await loadNest(); toast("Saved"); show("us");
      } else if (rep) {
        await api("/api/recurring", { method: "POST", body: { ...body, freq: rep, log_now: $("paidNow").checked } });
        await loadNest(); toast(mode === "income" ? "Payday added" : "Bill added"); show("home"); bunnyHop();
      } else {
        await api("/api/entries", { method: "POST", body });
        MONTH = ym(date); await loadNest();
        toast(mode === "income" ? "Income added" : "Expense added"); show("home"); bunnyHop();
      }
    } catch (e) { $("err").textContent = e.message; }
    finally { busy($("goBtn"), false); }
  };
  $("delRec").onclick = async () => {
    const r = editing?.x; if (!r) return;
    if (!(await ask(`Delete ${r.label}?`, "It stops showing up as due. Anything already logged stays.", "Delete"))) return;
    try { await api("/api/recurring/" + r.id, { method: "DELETE" }); editing = null; await loadNest(); toast("Deleted"); show("us"); }
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
      await api("/api/settlements", { method: "POST", body: { from_id: settling.from.id, to_id: settling.to.id, amount, date: today() } });
      $("settleDlg").close(); await loadNest(); toast("Marked as paid ♡");
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

  // ---------- nest settings ----------
  function drawSwatches(box) {
    box.innerHTML = "";
    THEMES.forEach((t) => {
      const b = document.createElement("button"); b.type = "button"; b.setAttribute("aria-pressed", NEST.accent === t.id ? "true" : "false");
      b.innerHTML = `<i style="background:${t.c}"></i>${t.n}`;
      b.onclick = async () => {
        NEST.accent = t.id; render(); drawSwatches(box);
        try { await api("/api/nest", { method: "PATCH", body: { accent: t.id } }); } catch (e) { toast(e.message); }
      };
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

  async function jarMove(direction) {
    const v = parseFloat($("jarAmt").value);
    if (!(v > 0)) { toast("Enter an amount first."); $("jarAmt").focus(); return; }
    try {
      await api("/api/jar", { method: "POST", body: { amount: v, direction } });
      $("jarAmt").value = ""; await loadNest(); toast(direction === "in" ? "Added to the jar" : "Taken out of the jar");
    } catch (e) { toast(e.message); }
  }
  $("jarIn").onclick = () => jarMove("in");
  $("jarOut").onclick = () => jarMove("out");
  $("editGoal").onclick = () => { $("gName").value = NEST.goal_name; $("gTarget").value = NEST.goal_target / 100; $("gErr").textContent = ""; $("goalDlg").showModal(); };
  $("gCancel").onclick = () => $("goalDlg").close();
  $("gSave").onclick = async () => {
    try { await api("/api/nest", { method: "PATCH", body: { goal_name: $("gName").value, goal_target: parseFloat($("gTarget").value) } }); $("goalDlg").close(); await loadNest(); }
    catch (e) { $("gErr").textContent = e.message; }
  };

  // invite
  $("copyInvite").onclick = async () => {
    try { await navigator.clipboard.writeText(inviteUrl()); toast("Link copied"); } catch { toast("Couldn't copy. Press and hold the link instead."); }
  };
  $("shareInvite").onclick = async () => {
    try { await navigator.share({ title: "Join our Honeybun budget", text: "Join our budget on Honeybun 🐰", url: inviteUrl() }); } catch {}
  };
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

  // ---------- tutorial ----------
  const ICONS = {
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>',
    heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>',
  };
  let step = 0;
  const STEPS = () => [
    { art: '<img src="/icon-192.png" alt="">', t: `Welcome, ${ME.name}`, p: "Pick your little buddy. It shows next to everything you add.", extra: "buddy" },
    { art: ICONS.plus, t: "Add money in or out", p: "Tap + to log what you spend or earn. Split it evenly, by percent, or set what's owed. Tap anything later to edit it." },
    { art: ICONS.cal, t: "Bills & paydays", p: "Add rent, subscriptions, and paychecks once. Home shows what's due before your next payday." },
    { art: ICONS.heart, t: "Do it together", p: MEMBERS.length < 2 ? "Invite your partner from Together. Then pick a look you both like:" : "Together shows who owes whom, so you can mark it paid. Pick a look you both like:", extra: "theme" },
  ];
  function drawTour() {
    const steps = STEPS(), st = steps[step];
    $("tourArt").innerHTML = st.art; $("tourT").textContent = st.t; $("tourP").textContent = st.p;
    const ex = $("tourExtra"); ex.innerHTML = "";
    if (st.extra === "buddy") {
      const g = document.createElement("div"); g.className = "emojis"; g.style.marginTop = "14px";
      const mine = meMember();
      EMOJIS.forEach((e) => {
        const b = document.createElement("button"); b.type = "button"; b.textContent = e;
        b.setAttribute("aria-pressed", mine && mine.emoji === e ? "true" : "false");
        b.onclick = async () => { if (mine) mine.emoji = e; drawTour(); try { await api("/api/me", { method: "PATCH", body: { emoji: e } }); } catch (err) { toast(err.message); } };
        g.appendChild(b);
      });
      ex.appendChild(g);
    }
    if (st.extra === "theme") { const b = document.createElement("div"); b.className = "swatches"; ex.appendChild(b); drawSwatches(b); }
    $("tourDots").innerHTML = steps.map((_, i) => `<i class="${i === step ? "on" : ""}"></i>`).join("");
    $("tourNext").textContent = step === steps.length - 1 ? "Let's go" : "Next";
    $("tourSkip").hidden = step === steps.length - 1;
  }
  function openTour() { step = 0; drawTour(); $("tour").showModal(); }
  $("tour").addEventListener("close", () => { store.set("hb-tour-" + ME.id, "1"); render(); });
  $("tourNext").onclick = () => { if (step < STEPS().length - 1) { step++; drawTour(); } else $("tour").close(); };
  $("tourSkip").onclick = () => $("tour").close();
  $("replayTour").onclick = openTour;

  // ---------- start ----------
  (async () => {
    if (resetToken) { show("reset"); return; }
    try { await afterAuth(); }
    catch (e) {
      if (e.status === 401) { authMode = pendingCode ? "signup" : store.get("hb-had-account") ? "login" : "signup"; showAuth(); }
      else { showAuth(); $("authErr").textContent = e.message; }
    }
  })();
})();
