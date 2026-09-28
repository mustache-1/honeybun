// If the app hasn't started after 8 seconds (usually mid-deploy, when files are half-updated),
// show a friendly message and refresh automatically (up to 2 times).
(function () {
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
