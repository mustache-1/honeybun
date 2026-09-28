// Honeybun boot helpers: forced dark theme, Bun assistant, mobile polish, deploy recovery.
(function () {
  var root = document.documentElement;

  // Honeybun is dark-mode only.
  root.setAttribute("data-theme", "dark");
  try { localStorage.removeItem("hb-theme"); } catch (e) {}

  // iPhone / iPad + installed Home Screen detection.
  var ua = navigator.userAgent || "";
  var isiOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  var standalone = !!navigator.standalone || (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches);
  root.setAttribute("data-ios", isiOS ? "1" : "0");
  root.setAttribute("data-standalone", standalone ? "1" : "0");

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

  function syncThemeColor() {
    var meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) {
      meta = document.createElement("meta");
      meta.name = "theme-color";
      document.head.appendChild(meta);
    }
    meta.content = "#17151b";
  }

  function removeThemeToggle() {
    var btn = document.getElementById("hbThemeToggle");
    if (btn) btn.remove();
  }

  function syncVisualViewport() {
    if (!window.visualViewport) return;
    var vv = window.visualViewport;
    var bottomGap = Math.max(0, window.innerHeight - (vv.height + vv.offsetTop));
    root.style.setProperty("--hb-vv-bottom", bottomGap + "px");
  }

  function initUiBits() {
    root.setAttribute("data-theme", "dark");
    addStyle("/hb-v8-tweaks.css?v=4", "data-hb-v8-tweaks");
    addStyle("/hb-mobile.css?v=5", "data-hb-mobile");
    addStyle("/hb-mobile-hotfix.css?v=1", "data-hb-mobile-hotfix");
    addScript("/hb-bun.js?v=2", "data-hb-bun");
    removeThemeToggle();
    syncThemeColor();
    syncVisualViewport();
    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", syncVisualViewport);
      window.visualViewport.addEventListener("scroll", syncVisualViewport);
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initUiBits);
  else initUiBits();

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
