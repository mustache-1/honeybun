// Honeybun boot helpers: theme + Bun assistant + deploy recovery.
(function () {
  var savedTheme = null;
  try { savedTheme = localStorage.getItem("hb-theme"); } catch (e) {}
  if (savedTheme === "light" || savedTheme === "dark") document.documentElement.setAttribute("data-theme", savedTheme);

  function addRefinementStyles() {
    if (document.querySelector('link[data-hb-v8-tweaks]')) return;
    var l = document.createElement("link"); l.rel = "stylesheet"; l.href = "/hb-v8-tweaks.css?v=3"; l.setAttribute("data-hb-v8-tweaks", "1"); document.head.appendChild(l);
  }
  function loadBunAssistant(){
    if(document.querySelector('script[data-hb-bun]')) return;
    var s=document.createElement("script"); s.src="/hb-bun.js?v=1"; s.defer=true; s.setAttribute("data-hb-bun","1"); document.head.appendChild(s);
  }
  function currentTheme() {
    var explicit = document.documentElement.getAttribute("data-theme");
    if (explicit === "light" || explicit === "dark") return explicit;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  function mountThemeToggle() {
    if (document.getElementById("hbThemeToggle")) return;
    var top = document.getElementById("topBar") || document.querySelector(".top"); if (!top) return;
    var btn = document.createElement("button"); btn.type = "button"; btn.id = "hbThemeToggle"; btn.className = "hb-theme-toggle"; btn.setAttribute("aria-label", "Switch light or dark mode");
    function paint() { var t=currentTheme(); btn.innerHTML='<span class="hb-theme-icon">'+(t==="dark"?"☾":"☀")+'</span><span class="hb-theme-label">'+(t==="dark"?"Dark":"Light")+'</span>'; btn.title="Switch to "+(t==="dark"?"light":"dark")+" mode"; }
    btn.addEventListener("click",function(){var next=currentTheme()==="dark"?"light":"dark";document.documentElement.setAttribute("data-theme",next);try{localStorage.setItem("hb-theme",next)}catch(e){}paint();});
    top.appendChild(btn); paint();
  }
  function initUiBits() { addRefinementStyles(); loadBunAssistant(); mountThemeToggle(); }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initUiBits); else initUiBits();

  setTimeout(function () {
    if (window.__hbStarted) return;
    var tries = 0; try { tries = +(sessionStorage.getItem("hb-boot") || 0); } catch (e) {}
    var msg = document.getElementById("bootMsg"); if (msg) msg.hidden = false;
    if (tries < 2) { try { sessionStorage.setItem("hb-boot", String(tries + 1)); } catch (e) {} setTimeout(function () { location.reload(); }, 3000); }
    else { var btn = document.getElementById("bootBtn"); if (btn) { btn.hidden = false; btn.onclick = function () { try { sessionStorage.removeItem("hb-boot"); } catch (e) {} location.reload(); }; } }
  }, 8000);
})();
