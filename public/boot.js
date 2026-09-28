// Honeybun boot helpers: theme, Bun assistant, mobile polish, deploy recovery.
(function () {
  var root = document.documentElement;

  // Apply saved theme as early as possible.
  var savedTheme = null;
  try { savedTheme = localStorage.getItem("hb-theme"); } catch (e) {}
  if (savedTheme === "light" || savedTheme === "dark") root.setAttribute("data-theme", savedTheme);

  // iPhone / iPad + installed Home Screen detection.
  var ua = navigator.userAgent || "";
  var isiOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  var standalone = !!navigator.standalone || (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches);
  root.setAttribute("data-ios", isiOS ? "1" : "0");
  root.setAttribute("data-standalone", standalone ? "1" : "0");

  // Better iOS standalone appearance. Safari's URL bar itself cannot be hidden in a normal browser tab;
  // installed Home Screen mode removes it and Honeybun already ships as a PWA.
  var appleStatus = document.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]');
  if (appleStatus) appleStatus.setAttribute("content", "black-translucent");

  function addStyle(href, attr) {
    if (document.querySelector('link[' + attr + ']')) return;
    var l = document.createElement("link");
    l.rel = "stylesheet";
    l.href = href;
    l.setAttribute(attr, "1");
    document.head.appendChild(l);
  }

  function addScript(src, attr) {
    if (document.querySelector('script[' + attr + ']')) return;
    var s = document.createElement("script");
    s.src = src;
    s.defer = true;
    s.setAttribute(attr, "1");
    document.head.appendChild(s);
  }

  function currentTheme() {
    var explicit = root.getAttribute("data-theme");
    if (explicit === "light" || explicit === "dark") return explicit;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function syncThemeColor() {
    var meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) {
      meta = document.createElement("meta");
      meta.name = "theme-color";
      document.head.appendChild(meta);
    }
    meta.content = currentTheme() === "dark" ? "#19171c" : "#f7f5f2";
  }

  function mountThemeToggle() {
    if (document.getElementById("hbThemeToggle")) return;
    var top = document.getElementById("topBar") || document.querySelector("header.top") || document.querySelector(".top");
    if (!top) return;

    var btn = document.createElement("button");
    btn.type = "button";
    btn.id = "hbThemeToggle";
    btn.className = "hb-theme-toggle";
    btn.setAttribute("aria-label", "Switch light or dark mode");

    function paint() {
      var t = currentTheme();
      btn.innerHTML = '<span class="hb-theme-icon">' + (t === "dark" ? "☾" : "☀") + '</span><span class="hb-theme-label">' + (t === "dark" ? "Dark" : "Light") + '</span>';
      btn.title = "Switch to " + (t === "dark" ? "light" : "dark") + " mode";
      syncThemeColor();
    }

    btn.addEventListener("click", function () {
      var next = currentTheme() === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("hb-theme", next); } catch (e) {}
      paint();
    });

    top.appendChild(btn);
    paint();
  }

  function mountIOSInstallTip() {
    if (!isiOS || standalone || document.getElementById("hbIOSInstall")) return;
    try { if (localStorage.getItem("hb-ios-tip-dismissed") === "1") return; } catch (e) {}

    var tip = document.createElement("div");
    tip.id = "hbIOSInstall";
    tip.className = "hb-ios-install";
    tip.innerHTML = '<div class="bunny">🐰</div><div class="txt"><b>Make Honeybun feel like a real iPhone app</b>Tap Share in Safari, then <strong>Add to Home Screen</strong>. It opens full-screen without the Safari URL bar.</div><button type="button" aria-label="Dismiss">×</button>';
    tip.querySelector("button").addEventListener("click", function () {
      tip.remove();
      try { localStorage.setItem("hb-ios-tip-dismissed", "1"); } catch (e) {}
    });
    document.body.appendChild(tip);
  }

  function initUiBits() {
    addStyle("/hb-v8-tweaks.css?v=3", "data-hb-v8-tweaks");
    addStyle("/hb-mobile.css?v=1", "data-hb-mobile");
    addScript("/hb-bun.js?v=1", "data-hb-bun");
    mountThemeToggle();
    mountIOSInstallTip();
    syncThemeColor();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initUiBits);
  else initUiBits();

  // If the app hasn't started after 8 seconds (usually mid-deploy, when files are half-updated),
  // show a friendly message and refresh automatically (up to 2 times).
  setTimeout(function () {
    if (window.__hbStarted) return;
    var tries = 0;
    try { tries = +(sessionStorage.getItem("hb-boot") || 0); } catch (e) {}
    var msg = document.getElementById("bootMsg");
    if (msg) msg.hidden = false;
    if (tries < 2) {
      try { sessionStorage.setItem("hb-boot", String(tries + 1)); } catch (e) {}
      setTimeout(function () { location.reload(); }, 3000);
    } else {
      var btn = document.getElementById("bootBtn");
      if (btn) { btn.hidden = false; btn.onclick = function () { try { sessionStorage.removeItem("hb-boot"); } catch (e) {} location.reload(); }; }
    }
  }, 8000);
})();
