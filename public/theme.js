// Applies the saved light/dark choice before the page paints, so there's no flash. "auto" follows the device.
(function () {
  try {
    var t = localStorage.getItem("hb-theme");
    if (t === "light" || t === "dark") document.documentElement.setAttribute("data-theme", t);
  } catch (e) {}
})();
