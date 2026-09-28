// Honeybun boot helpers: light theme, Bun assistant, mobile polish, deploy recovery.
(function () {
  var root = document.documentElement;

  // Honeybun is light-mode only now.
  root.setAttribute("data-theme", "light");
  try { localStorage.removeItem("hb-theme"); } catch (e) {}

  // iPhone / iPad + installed Home Screen detection.
  var ua = navigator.userAgent || "";
  var isiOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  var standalone = !!navigator.standalone || (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches);
  root.setAttribute("data-ios", isiOS ? "1" : "0");
  root.setAttribute("data-standalone", standalone ? "1" : "0");

  // Use a light iPhone status bar treatment.
  var appleStatus = document.querySelector('meta[name="apple-mobile-web-app-status-bar-style"]');
  if (appleStatus) appleStatus.setAttribute("content", "default");

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

  function syncThemeColor() {
    var meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) {
      meta = document.createElement("meta");
      meta.name = "theme-color";
      document.head.appendChild(meta);
    }
    meta.content = "#f7f5f2";
  }

  function removeThemeToggle() {
    var btn = document.getElementById("hbThemeToggle");
    if (btn) btn.remove();
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
    root.setAttribute("data-theme", "light");
    addStyle("/hb-v8-tweaks.css?v=3", "data-hb-v8-tweaks");
    addStyle("/hb-mobile.css?v=3", "data-hb-mobile");
    addScript("/hb-bun.js?v=1", "data-hb-bun");
    removeThemeToggle();
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
      if (btn) {
        btn.hidden = false;
        btn.onclick = function () {
          try { sessionStorage.removeItem("hb-boot"); } catch (e) {}
          location.reload();
        };
      }
    }
  }, 8000);
})();
