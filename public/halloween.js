// Honeybun Halloween: a glowing moon, bats, spiders, webs, fog and a little graveyard behind and above the app.
// theme.js decides whether it's on (October, or forced in Settings) and adds html.hb-halloween before the first paint;
// this file builds the scenery, follows the current screen (landing page or app), and freezes it while the window is hidden.
(function () {
  var root = document.documentElement;
  var BAT = '<svg viewBox="0 0 64 32"><path fill="#0B080F" d="M32 11c-1.6-3.6-3.6-5-3.6-5l.8 4.6C26 9.4 22 4.6 12 5c4 3 5.4 7.4 3.4 11.6 3-2.2 7.2-2 9.4 1.2 1.2-3 4.2-4 7.2-2 3-2 6-1 7.2 2 2.2-3.2 6.4-3.4 9.4-1.2-2-4.2-.6-8.6 3.4-11.6-10-.4-14 4.4-17.2 5.6l.8-4.6s-2 1.4-3.6 5z"/><circle cx="29.5" cy="12" r=".9" fill="#F28C38"/><circle cx="34.5" cy="12" r=".9" fill="#F28C38"/></svg>';
  var WEB = '<svg viewBox="0 0 100 100" fill="none" stroke="#D8CCE4" stroke-width=".7"><path d="M0 0L100 22M0 0L92 70M0 0L55 100M0 0L18 100M0 0L100 0M0 0L0 100"/><path d="M0 16Q9 14 14 5 17 14 24 18 17 24 12 34 7 24 0 16M0 34Q18 28 27 10 34 28 48 34 36 45 30 62 17 48 0 34M0 54Q28 46 40 16 52 44 72 50 54 64 46 84 25 70 0 54M0 76Q38 66 54 22 70 58 96 66 72 84 62 100"/></svg>';
  var SPIDER = '<svg viewBox="0 0 28 26"><g stroke="#3a2f45" stroke-width="1.6" fill="none" stroke-linecap="round"><path d="M10 12L3 7M10 14L2 14M10 16L3 21M11 18L6 25M18 12L25 7M18 14L26 14M18 16L25 21M17 18L22 25"/></g><ellipse cx="14" cy="15" rx="5" ry="6" fill="#241c2c" stroke="#56466a" stroke-width="1"/><circle cx="14" cy="8.5" r="3.4" fill="#241c2c" stroke="#56466a" stroke-width="1"/><circle cx="12.8" cy="8.2" r=".8" fill="#F28C38"/><circle cx="15.2" cy="8.2" r=".8" fill="#F28C38"/></svg>';
  function rnd(a, b) { return a + Math.random() * (b - a); }
  function flyer(top, size, dur, delay, bob, rev, cls) {
    return '<div class="hbh-fly' + (rev ? " rev" : "") + (cls ? " " + cls : "") + '" style="top:' + top + ';animation-duration:' + dur + 's;animation-delay:-' + delay + 's"><div style="animation-duration:' + bob + 's"><span class="hbh-bat" style="width:' + size + 'px;height:' + (size / 2) + 'px">' + BAT + '</span></div></div>';
  }
  function spider(pos, lo, hi, cls, delay) {
    return '<div class="hbh-spider ' + (cls || "") + '" style="' + pos + ';--lo:' + lo + 'px;--hi:' + hi + 'px;animation-delay:-' + delay + 's"><div class="thread" style="animation-delay:-' + delay + 's"></div>' + SPIDER + '</div>';
  }

  var HAT = '<g class="hbh-hat"><path d="M56 70 Q80 56 104 70 Q80 78 56 70z" fill="#2a1b3d" stroke="#2B2733" stroke-width="3" stroke-linejoin="round"/><path d="M66 68 L76 24 Q80 14 88 28 L96 68 Q80 74 66 68z" fill="#3a2452" stroke="#2B2733" stroke-width="3" stroke-linejoin="round"/><path d="M68 60 Q80 66 94 60 L95.5 66 Q80 72 67 66z" fill="#F28C38"/><rect x="77" y="60" width="7" height="8" rx="1.5" fill="#F6C94E"/><path d="M84 20l1.6 3.6 3.9.4-2.9 2.6.9 3.8-3.5-2-3.5 2 .9-3.8-2.9-2.6 3.9-.4z" fill="#F6C94E"/></g>';
  // the mascot on the landing page puts on a witch hat
  function hats(on) {
    document.querySelectorAll('.hb-bun-body').forEach(function (b) {
      var h = b.querySelector('.hbh-hat');
      if (on && !h) b.insertAdjacentHTML('beforeend', HAT); else if (!on && h) h.remove();
    });
  }

  var sky = null, fx = null;
  function build() {
    if (sky || !document.body) return;
    var stars = "", embers = "", i;
    for (i = 0; i < 46; i++) stars += '<i class="hbh-star" style="top:' + rnd(0, 70).toFixed(1) + '%;left:' + rnd(0, 100).toFixed(1) + '%;animation-duration:' + rnd(2, 5).toFixed(1) + 's;animation-delay:-' + rnd(0, 5).toFixed(1) + 's;transform:scale(' + rnd(.6, 1.5).toFixed(2) + ')"></i>';
    for (i = 0; i < 16; i++) embers += '<i class="hbh-ember" style="left:' + rnd(0, 100).toFixed(1) + '%;animation-duration:' + rnd(9, 18).toFixed(1) + 's;animation-delay:-' + rnd(0, 18).toFixed(1) + 's;transform:scale(' + rnd(.5, 1.2).toFixed(2) + ')"></i>';
    sky = document.createElement("div");
    sky.className = "hbh-sky"; sky.setAttribute("aria-hidden", "true");
    sky.innerHTML = stars +
      '<div class="hbh-moonwrap"><div class="hbh-halo"></div><div class="hbh-moon"><i style="width:18%;height:18%;top:22%;left:52%"></i><i style="width:12%;height:12%;top:56%;left:26%"></i><i style="width:9%;height:9%;top:64%;left:62%"></i><i style="width:7%;height:7%;top:36%;left:24%"></i></div>' +
      '<div class="hbh-cloud" style="top:30%;left:-40%;width:140%;animation-duration:26s"></div><div class="hbh-cloud" style="top:68%;left:-40%;width:90%;animation-duration:34s;animation-delay:-14s;opacity:.7"></div>' +
      '<div class="hbh-orbit" style="animation-duration:14s"><span class="hbh-bat">' + BAT + '</span></div><div class="hbh-orbit" style="animation-duration:19s;animation-direction:reverse;inset:-85%"><span class="hbh-bat">' + BAT + '</span></div></div>' +
      '<div class="hbh-web tl">' + WEB + '</div><div class="hbh-web tr">' + WEB + '</div><div class="hbh-web bl">' + WEB + '</div>' +
      embers +
      '<div class="hbh-fog"></div><div class="hbh-fog b"></div>' +
      '<svg class="hbh-grave" viewBox="0 0 800 140" preserveAspectRatio="xMidYMax slice"><path fill="#0D0A11" d="M0 140V104q70-18 150-8t180 4 220-10 250 14v36z"/>' +
      '<g fill="#1C1524"><path d="M70 140V84q0-24 24-24t24 24v56z"/><path d="M190 140V96q0-16 16-16t16 16v44z"/><path d="M560 140V90q0-18 18-18t18 18v50z"/><path d="M680 140V70h9V56h9v14h9v9h-9v61z"/><path d="M380 140V110l8-6 8 6v30z"/></g>' +
      '<g class="hbh-lantern"><circle cx="150" cy="120" r="12" fill="#E77C27"/><path d="M144 116l3-4 3 4zM152 116l3-4 3 4zM145 124q5 4 10 0" fill="#FFD27A" stroke="#FFD27A" stroke-width="1.2"/><circle cx="150" cy="120" r="22" fill="rgba(255,150,60,.18)"/></g>' +
      '<g class="hbh-lantern b"><circle cx="630" cy="126" r="9" fill="#E77C27"/><path d="M626 123l2-3 2 3zM632 123l2-3 2 3zM626 129q4 3 8 0" fill="#FFD27A" stroke="#FFD27A"/><circle cx="630" cy="126" r="18" fill="rgba(255,150,60,.16)"/></g>' +
      '<path d="M150 108v-4" stroke="#3E6B2E" stroke-width="2.5"/><path d="M630 117v-3" stroke="#3E6B2E" stroke-width="2"/></svg>';
    document.body.insertBefore(sky, document.body.firstChild);

    fx = document.createElement("div");
    fx.className = "hbh-fx"; fx.setAttribute("aria-hidden", "true");
    fx.innerHTML =
      flyer("14%", 44, 17, 2, 1.6, false) + flyer("30%", 30, 23, 11, 2.1, true) + flyer("55%", 38, 20, 6, 1.8, false) +
      flyer("72%", 26, 27, 17, 2.4, true, "hbh-desk") + flyer("40%", 50, 29, 21, 1.9, false, "hbh-desk") + flyer("22%", 24, 25, 4, 2.2, true) +
      spider("left:46%", 30, 70, "for-app hbh-desk", 0) + spider("right:4%", 20, 60, "for-app hbh-desk", 2) + spider("left:44%", 18, 44, "for-app hbh-phone", 1) +
      spider("left:40%", 90, 150, "for-landing hbh-desk", 0) + spider("right:8%", 70, 120, "for-landing", 3) +
      '<div class="hbh-fxweb hbh-desk" style="top:-4px;right:-4px;width:110px;height:110px;transform:scaleX(-1)">' + WEB + '</div>';
    document.body.appendChild(fx);
  }
  function teardown() {
    if (sky) { sky.remove(); sky = null; }
    if (fx) { fx.remove(); fx = null; }
  }

  // landing page and app get different moon and spider placement
  function syncMode() {
    var nav = document.getElementById("nav");
    var inApp = !!nav && !nav.hidden;
    root.classList.toggle("hbp-app", inApp);
    root.classList.toggle("hbp-landing", !inApp);
  }

  function refresh() {
    var on = typeof window.hbHalloweenActive === "function" && window.hbHalloweenActive();
    root.classList.toggle("hb-halloween", on);
    hats(on);
    if (on) { build(); syncMode(); } else { teardown(); root.classList.remove("hbp-app", "hbp-landing"); }
    return on;
  }
  window.hbHalloweenRefresh = refresh;

  function start() {
    var nav = document.getElementById("nav");
    if (nav && window.MutationObserver) new MutationObserver(function () { if (sky) syncMode(); }).observe(nav, { attributes: true, attributeFilter: ["hidden"] });
    document.addEventListener("visibilitychange", function () { root.classList.toggle("hbh-paused", document.hidden); });
    root.classList.toggle("hbh-paused", document.hidden);
    refresh();
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
