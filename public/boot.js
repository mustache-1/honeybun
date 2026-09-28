// Honeybun boot helpers: forced dark theme, wired rebuild UI, Bun assistant, deploy recovery.
(function () {
  var root = document.documentElement;

  root.setAttribute("data-theme", "dark");
  try { localStorage.removeItem("hb-theme"); } catch (e) {}

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
    meta.content = "#141217";
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

    // Keep the real app wired, then apply the approved preview look on top.
    addStyle("/hb-rebuild.css?v=3", "data-hb-rebuild");
    addStyle("/hb-preview-parity.css?v=1", "data-hb-preview-parity");

    // Existing functional helper remains wired.
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
