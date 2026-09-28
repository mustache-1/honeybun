// Honeybun boot helpers: theme + deploy recovery.
(function () {
  // Apply saved theme as early as possible.
  var savedTheme = null;
  try { savedTheme = localStorage.getItem("hb-theme"); } catch (e) {}
  if (savedTheme === "light" || savedTheme === "dark") {
    document.documentElement.setAttribute("data-theme", savedTheme);
  }

  function addRefinementStyles() {
    if (document.querySelector('link[data-hb-v8-tweaks]')) return;
    var l = document.createElement("link");
    l.rel = "stylesheet";
    l.href = "/hb-v8-tweaks.css?v=1";
    l.setAttribute("data-hb-v8-tweaks", "1");
    document.head.appendChild(l);
  }

  function currentTheme() {
    var explicit = document.documentElement.getAttribute("data-theme");
    if (explicit === "light" || explicit === "dark") return explicit;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function mountThemeToggle() {
    if (document.getElementById("hbThemeToggle")) return;
    var top = document.getElementById("topBar") || document.querySelector(".top");
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
    }

    btn.addEventListener("click", function () {
      var next = currentTheme() === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", next);
      try { localStorage.setItem("hb-theme", next); } catch (e) {}
      paint();
    });

    top.appendChild(btn);
    paint();
  }

  function initUiBits() {
    addRefinementStyles();
    mountThemeToggle();
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
