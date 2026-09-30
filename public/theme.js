// Applies the saved light/dark choice before the page paints, so there's no flash. Dark unless someone picked otherwise; "auto" follows the device.
(function () {
  try {
    // dark is the default look; "auto" (follow the device) and "light" are choices in Settings
    // one time: older versions saved "auto" for everyone without asking, so reset that to the new dark default
    if (localStorage.getItem("hb-theme-v") !== "2") {
      if (localStorage.getItem("hb-theme") === "auto") localStorage.removeItem("hb-theme");
      localStorage.setItem("hb-theme-v", "2");
    }
    var t = localStorage.getItem("hb-theme") || "dark";
    if (t === "light" || t === "dark") document.documentElement.setAttribute("data-theme", t);
  } catch (e) {}

  // Halloween: on from Sept 29 through Oct 31, and only in a dark theme.
  // ?halloween=1 forces it on for this browser, ?halloween=0 goes back to the calendar.
  try {
    var q = /[?&]halloween=([01])/.exec(location.search);
    if (q) { if (q[1] === "1") localStorage.setItem("hb-halloween", "on"); else localStorage.removeItem("hb-halloween"); }
  } catch (e) {}
  window.hbHalloweenActive = function () {
    try {
      var pref = localStorage.getItem("hb-halloween");
      if (pref === "off") return false;
      var th = localStorage.getItem("hb-theme") || "dark";
      var light = th === "light" || (th === "auto" && window.matchMedia && matchMedia("(prefers-color-scheme: light)").matches);
      if (light) return false;
      if (pref === "on") return true;
      var d = new Date(), m = d.getMonth(), day = d.getDate();
      return m === 9 || (m === 8 && day >= 29);
    } catch (e) { return false; }
  };
  if (window.hbHalloweenActive()) document.documentElement.classList.add("hb-halloween");
})();
