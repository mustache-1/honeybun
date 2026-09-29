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
})();
