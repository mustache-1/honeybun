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

  // ---------- helpers ----------
  const $ = (id) => document.getElementById(id);
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const fmt = (n) => (n < 0 ? "−" : "") + "$" + Math.abs(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const today = () => { const d = new Date(); return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0"); };
  const ym = (d) => d.slice(0, 7);
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  };
  function monthName(m, short) {
    const [y, mo] = m.split("-").map(Number);
    return new Date(y, mo - 1, 1).toLocaleDateString(undefined, short ? { month: "short", year: "2-digit" } : { month: "long", year: "numeric" });
  }
  function toast(t) {
    const el = $("toast"); el.textContent = t; el.classList.add("show");
    clearTimeout(toast.t); toast.t = setTimeout(() => el.classList.remove("show"), 1900);
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
    try { res = await fetch(path, opts); }
    catch { throw new Error("You're offline. Check your connection and try again."); }
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
  let ME = null, NEST = null, MEMBERS = [], ENTRIES = [];
  let MONTH = today().slice(0, 7);
  let screen = "loading", mode = "expense", cat = "groc", who = null, shared = true, filter = null, authMode = "signup";
  let pendingCode = null;
  {
    const m = location.pathname.match(/^\/join\/([A-Za-z0-9-]{4,20})\/?$/);
    if (m) pendingCode = m[1];
  }
  const member = (id) => MEMBERS.find((m) => m.id === id) || { name: "Someone", emoji: "❔", color: "#EEE" };
  const meMember = () => MEMBERS.find((m) => m.id === ME?.id);

  // ---------- screens ----------
  const APP_SCREENS = ["home", "add", "us"];
  function show(s) {
    screen = s;
    ["loading", "auth", "setup", "home", "add", "us"].forEach((k) => ($("scr-" + k).hidden = k !== s));
    const inApp = APP_SCREENS.includes(s);
    $("nav").hidden = !inApp; $("topBar").hidden = !inApp;
    document.querySelectorAll("nav.bottom [data-go]").forEach((b) => b.dataset.go === s ? b.setAttribute("aria-current", "page") : b.removeAttribute("aria-current"));
    window.scrollTo(0, 0);
    if (s === "add") { $("err").textContent = ""; setTimeout(() => $("amt").focus(), 60); }
    if (inApp) render();
  }
  document.querySelectorAll("nav.bottom [data-go]").forEach((b) => (b.onclick = () => show(b.dataset.go)));

  // ---------- auth ----------
  function showAuth() {
    $("inviteNotice").hidden = !pendingCode;
    setAuthMode(authMode);
    show("auth");
  }
  function setAuthMode(m) {
    authMode = m;
    document.querySelectorAll("[data-auth]").forEach((b) => b.setAttribute("aria-selected", b.dataset.auth === m ? "true" : "false"));
    $("nameField").hidden = m !== "signup";
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
      $("authErr").textContent = e.message;
      if (e.status === 409) setTimeout(() => { setAuthMode("login"); $("authErr").textContent = e.message; }, 0);
    } finally { busy($("authBtn"), false); }
  };

  async function afterAuth() {
    const me = await api("/api/me");
    ME = me.user;
    store.set("hb-had-account", "1"); // next time on this device, show "Log in" first
    if (pendingCode) {
      try {
        await api("/api/nests/join", { method: "POST", body: { code: pendingCode } });
        toast("You joined the budget");
      } catch (e) { $("setupErr").textContent = e.message; toast(e.message); }
      pendingCode = null;
      history.replaceState(null, "", "/");
      return afterAuth();
    }
    if (!me.nest_id) {
      $("setupHi").textContent = "Hi, " + ME.name + "!";
      show("setup");
      return;
    }
    await loadNest();
    show("home");
    bunnyHop();
    if (!store.get("hb-tour-" + ME.id)) setTimeout(openTour, 350);
  }

  async function logout() {
    try { await api("/api/logout", { method: "POST" }); } catch {}
    ME = null; NEST = null; MEMBERS = []; ENTRIES = []; filter = null;
    authMode = "login"; showAuth();
  }
  $("setupLogout").onclick = logout;
  $("logoutBtn").onclick = logout;

  // ---------- setup (start / join) ----------
  $("createNest").onclick = async () => {
    busy($("createNest"), true); $("setupErr").textContent = "";
    try { await api("/api/nests", { method: "POST", body: { name: $("newNestName").value } }); await afterAuth(); }
    catch (e) { $("setupErr").textContent = e.message; }
    finally { busy($("createNest"), false); }
  };
  $("joinNest").onclick = async () => {
    const code = $("joinCode").value.trim();
    if (!code) { $("setupErr").textContent = "Enter the invite code."; $("joinCode").focus(); return; }
    busy($("joinNest"), true); $("setupErr").textContent = "";
    try { await api("/api/nests/join", { method: "POST", body: { code } }); toast("You joined the budget"); await afterAuth(); }
    catch (e) { $("setupErr").textContent = e.message; }
    finally { busy($("joinNest"), false); }
  };

  // ---------- data ----------
  async function loadNest() {
    const d = await api("/api/nest?month=" + MONTH);
    ME = d.me; NEST = d.nest; MEMBERS = d.members;
    ENTRIES = d.entries.map((e) => ({ ...e, amount: e.amount_cents / 100, shared: !!e.shared }));
    if (!MEMBERS.some((m) => m.id === who)) who = ME.id;
    if (filter && !MEMBERS.some((m) => m.id === filter)) filter = null;
    if (APP_SCREENS.includes(screen)) render();
  }
  async function refresh() {
    if (!ME || !APP_SCREENS.includes(screen) || document.hidden) return;
    if (document.querySelector("dialog[open]") || (screen === "add" && $("amt").value)) return;
    try { await loadNest(); } catch {}
  }
  setInterval(refresh, 20000);
  document.addEventListener("visibilitychange", refresh);

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

  function entryLi(e) {
    const m = member(e.member_id), c = CATS.find((x) => x.id === e.category) || CATS[8], isIn = e.type === "income";
    const li = document.createElement("li");
    const d = new Date(e.date + "T00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" });
    li.innerHTML = `<div class="ic" style="${isIn ? "background:var(--mint-t)" : ""}">${isIn ? "💰" : c.e}</div>
      <div class="mid"><div class="t">${esc(e.label)}</div><div class="s">${esc(m.emoji)} ${esc(m.name)}, ${d}${isIn ? "" : e.shared ? ", split" : ", personal"}</div></div>
      <div class="amt ${isIn ? "in" : ""}">${isIn ? "+" : "−"}${fmt(e.amount)}</div>
      <button class="del" aria-label="Delete ${esc(e.label)}">✕</button>`;
    li.querySelector(".del").onclick = async () => {
      if (!(await ask("Remove this?", `${e.label}, ${fmt(e.amount)}`, "Remove"))) return;
      try { await api("/api/entries/" + e.id, { method: "DELETE" }); await loadNest(); }
      catch (err) { toast(err.message); }
    };
    return li;
  }

  function inviteUrl() { return location.origin + "/join/" + NEST.invite_code; }
  const prettyCode = (c) => c.slice(0, 4) + "-" + c.slice(4);

  function render() {
    if (!NEST) return;
    document.documentElement.setAttribute("data-accent", NEST.accent || "blueberry");
    $("monthLbl").textContent = monthName(MONTH, true);
    const names = MEMBERS.map((m) => m.name);
    $("hi").textContent = NEST.name || (MEMBERS.length === 2 ? `${names[0]} & ${names[1]}` : MEMBERS.length === 1 ? names[0] : "Our family");

    const all = ENTRIES, view = filter ? all.filter((e) => e.member_id === filter) : all;
    const inc = view.filter((e) => e.type === "income").reduce((s, e) => s + e.amount, 0);
    const out = view.filter((e) => e.type === "expense").reduce((s, e) => s + e.amount, 0);
    const left = inc - out;

    if (screen === "home") {
      $("leftLbl").textContent = filter ? member(filter).name + "'s balance" : "Left for us this month";
      $("leftAmt").textContent = fmt(left); $("leftAmt").classList.toggle("neg", left < 0);
      $("meter").style.width = inc > 0 ? Math.min(100, (out / inc) * 100) + "%" : out > 0 ? "100%" : "0";
      $("flowIn").textContent = "+" + fmt(inc) + " in"; $("flowOut").textContent = fmt(out) + " out";
      setBunny(left, inc, out, view.length > 0);

      const cp = $("couple"); cp.innerHTML = "";
      MEMBERS.forEach((m, i) => {
        if (i > 0 && MEMBERS.length === 2) { const h = document.createElement("span"); h.className = "heart"; h.textContent = "&"; h.setAttribute("aria-hidden", "true"); cp.appendChild(h); }
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
        const h = document.createElement("span"); h.className = "heart"; h.textContent = "&"; h.setAttribute("aria-hidden", "true");
        cp.append(h, b);
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

    if (screen === "add") {
      const c = $("cats"); c.innerHTML = "";
      CATS.forEach((k) => {
        const b = document.createElement("button"); b.type = "button"; b.innerHTML = `<b>${k.e}</b>${k.n}`;
        b.setAttribute("aria-pressed", k.id === cat ? "true" : "false"); b.onclick = () => { cat = k.id; render(); }; c.appendChild(b);
      });
      const w = $("whos"); w.innerHTML = "";
      MEMBERS.forEach((m) => {
        const b = document.createElement("button"); b.type = "button";
        b.innerHTML = `<i style="background:${esc(m.color)}">${esc(m.emoji)}</i>${esc(m.name)}`;
        b.setAttribute("aria-pressed", m.id === who ? "true" : "false"); b.onclick = () => { who = m.id; render(); }; w.appendChild(b);
      });
      const isInc = mode === "income";
      document.querySelectorAll("#scr-add .tabs button").forEach((b) => b.setAttribute("aria-selected", b.dataset.t === mode ? "true" : "false"));
      $("catField").hidden = isInc; $("splitField").hidden = isInc || MEMBERS.length < 2;
      $("lbl").placeholder = isInc ? "Paycheck" : "Date night tacos";
      $("whoLabel").textContent = isInc ? "Who got paid?" : "Who paid?";
      $("goBtn").textContent = isInc ? "Add income" : "Add expense";
      $("goBtn").classList.toggle("inc", isInc);
      $("spShared").setAttribute("aria-pressed", shared ? "true" : "false");
      $("spMine").setAttribute("aria-pressed", shared ? "false" : "true");
    }

    if (screen === "us") {
      // settle up
      const st = $("settle"); const sh = all.filter((e) => e.type === "expense" && e.shared);
      if (MEMBERS.length < 2 || !sh.length) st.innerHTML = `<p class="empty" style="margin:0">Split expenses show up here, with who owes whom.</p>`;
      else {
        const total = sh.reduce((s, e) => s + e.amount, 0), each = total / MEMBERS.length;
        const bal = MEMBERS.map((m) => ({ m, v: sh.filter((e) => e.member_id === m.id).reduce((s, e) => s + e.amount, 0) - each }));
        const debt = bal.filter((b) => b.v < -0.005).map((b) => ({ ...b, v: -b.v })), cred = bal.filter((b) => b.v > 0.005);
        let html = `<p style="margin:0;color:var(--soft);font-weight:700;font-size:.9rem">${fmt(total)} split, ${fmt(each)} each</p>`;
        let i = 0, j = 0, any = false;
        while (i < debt.length && j < cred.length) {
          const pay = Math.min(debt[i].v, cred[j].v); any = true;
          html += `<div class="owe"><span class="f">${esc(debt[i].m.emoji)}</span><span>${esc(debt[i].m.name)} owes ${esc(cred[j].m.name)}</span><span class="f">${esc(cred[j].m.emoji)}</span><span class="amt">${fmt(pay)}</span></div>`;
          debt[i].v -= pay; cred[j].v -= pay; if (debt[i].v < 0.005) i++; if (cred[j].v < 0.005) j++;
        }
        if (!any) html += `<div class="owe">You're all even ♡</div>`;
        st.innerHTML = html;
      }
      // jar
      const saved = NEST.goal_saved / 100, target = NEST.goal_target / 100;
      const pct = target > 0 ? Math.min(100, (saved / target) * 100) : 0, h = (80 * pct) / 100;
      $("jarFill").setAttribute("y", 98 - h); $("jarFill").setAttribute("height", h);
      $("goalName").textContent = NEST.goal_name;
      $("goalProg").textContent = fmt(saved) + " of " + fmt(target) + (pct >= 100 ? " · reached ♡" : " · " + Math.round(pct) + "%");
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
      // everything
      const l = $("list"); l.innerHTML = "";
      if (!all.length) l.innerHTML = `<li class="empty" style="justify-content:center;border:0">Nothing logged for ${esc(monthName(MONTH))}.</li>`;
      all.forEach((e) => l.appendChild(entryLi(e)));
      // invite
      $("inviteCode").textContent = prettyCode(NEST.invite_code);
      $("inviteLink").textContent = inviteUrl();
      $("shareInvite").hidden = !navigator.share;
      // settings
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

  // ---------- add entry ----------
  document.querySelectorAll("#scr-add .tabs button").forEach((b) => (b.onclick = () => { mode = b.dataset.t; $("err").textContent = ""; render(); }));
  $("spShared").onclick = () => { shared = true; render(); };
  $("spMine").onclick = () => { shared = false; render(); };
  $("goBtn").onclick = async () => {
    const amount = parseFloat($("amt").value);
    if (!(amount > 0)) { $("err").textContent = "Type an amount above $0 first."; $("amt").focus(); return; }
    const date = $("dt").value || today();
    busy($("goBtn"), true);
    try {
      await api("/api/entries", { method: "POST", body: {
        type: mode, amount, label: $("lbl").value.trim() || (mode === "income" ? "Paycheck" : CATS.find((c) => c.id === cat).n),
        category: cat, member_id: who, shared: mode === "expense" && shared && MEMBERS.length > 1, date,
      } });
      $("amt").value = ""; $("lbl").value = "";
      MONTH = ym(date);
      await loadNest();
      toast(mode === "income" ? "Income added" : "Expense added");
      show("home"); bunnyHop();
    } catch (e) { $("err").textContent = e.message; }
    finally { busy($("goBtn"), false); }
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

  $("jarAddBtn").onclick = async () => {
    const v = parseFloat($("jarAmt").value); if (!(v > 0)) return;
    try { await api("/api/nest/jar", { method: "POST", body: { amount: v } }); $("jarAmt").value = ""; await loadNest(); toast("Added to the jar"); }
    catch (e) { toast(e.message); }
  };
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
    if (!(await ask("Leave this budget?", alone ? "You're the only one here, so the budget and all its entries will be deleted." : "You can rejoin later with an invite code.", "Leave"))) return;
    try { await api("/api/nest/leave", { method: "POST" }); NEST = null; filter = null; await afterAuth(); } catch (e) { toast(e.message); }
  };

  // months
  async function shift(k) {
    const [y, mo] = MONTH.split("-").map(Number); const d = new Date(y, mo - 1 + k, 1);
    MONTH = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0");
    render();
    try { await loadNest(); } catch (e) { toast(e.message); }
  }
  $("prevM").onclick = () => shift(-1);
  $("nextM").onclick = () => shift(1);
  $("seeAll").onclick = () => { show("us"); setTimeout(() => $("allH").scrollIntoView({ behavior: "smooth" }), 40); };

  // ---------- tutorial ----------
  const ICONS = {
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    face: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="14" r="7.5"/><path d="M9.5 7C8.7 4 9 2 10 2s1.5 2.5 1.5 4.8M14.5 7c.8-3 .5-5-.5-5s-1.5 2.5-1.5 4.8"/><circle cx="9.5" cy="13.5" r=".8" fill="currentColor"/><circle cx="14.5" cy="13.5" r=".8" fill="currentColor"/><path d="M10.5 16.5q1.5 1.2 3 0"/></svg>',
    heart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/></svg>',
  };
  let step = 0;
  const STEPS = () => [
    { art: '<img src="/icon-192.png" alt="">', t: `Welcome, ${ME.name}`, p: "Pick your little buddy. It shows next to everything you add.", extra: "buddy" },
    { art: ICONS.plus, t: "Add money in or out", p: "Tap + to log a paycheck or something you bought. Pick who paid, and whether it's split or just yours." },
    { art: ICONS.face, t: "See how you're doing", p: "Your balance and the bunny update right away. Tap either of you to see just your own money." },
    { art: ICONS.heart, t: "Do it together", p: MEMBERS.length < 2 ? "Invite your partner from Together. Then pick a look you both like:" : "Together shows who owes whom and your savings jar. Pick a look you both like:", extra: "theme" },
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
        b.onclick = async () => {
          if (mine) mine.emoji = e; drawTour();
          try { await api("/api/me", { method: "PATCH", body: { emoji: e } }); } catch (err) { toast(err.message); }
        };
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
  $("dt").value = today();
  (async () => {
    try { await afterAuth(); }
    catch (e) {
      if (e.status === 401) { authMode = pendingCode ? "signup" : store.get("hb-had-account") ? "login" : "signup"; showAuth(); }
      else { show("auth"); $("authErr").textContent = e.message; }
    }
  })();
})();
