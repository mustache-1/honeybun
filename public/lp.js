// Landing page: live money counter, split demo, and scroll reveals. Loaded on every page but only touches #scr-landing.
(function () {
  var lp = document.getElementById("scr-landing");
  if (!lp) return;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var fmt = function (n) { return "$" + Math.abs(n).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
  var $ = function (id) { return document.getElementById(id); };

  // hero counter: starts the first time the card is on screen (the landing is hidden until the app decides to show it)
  var amt = $("lpAmt"), s1 = $("lpS1"), s2 = $("lpS2"), s3 = $("lpS3"), meter = $("lpMeter"), started = false;
  function setAmt(v) { var s = fmt(v).split("."); amt.innerHTML = s[0] + "<small>." + s[1] + "</small>"; }
  function count() {
    if (started) return; started = true;
    var t0 = performance.now(), dur = reduce ? 0 : 1600, ease = function (t) { return 1 - Math.pow(1 - t, 3); };
    function frame(now) {
      var p = dur ? Math.min(1, (now - t0) / dur) : 1, e = ease(p);
      setAmt(2006.32 * e); s1.textContent = fmt(2250 * e); s2.textContent = fmt(243.68 * e); s3.textContent = fmt(62.34 * e);
      if (p < 1) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
    setTimeout(function () { meter.style.width = "62%"; }, 150);
  }
  if (amt) {
    if ("IntersectionObserver" in window) {
      var io0 = new IntersectionObserver(function (en) { if (en[0].isIntersecting) { count(); io0.disconnect(); } });
      io0.observe(amt);
    } else count();
  }

  // split demo
  var total = 84, mode = "equal", sl = $("lpSl");
  if (sl) {
    var slLbl = $("lpSlLbl"), slVal = $("lpSlVal"), barA = $("lpBarA"), barB = $("lpBarB"), whoA = $("lpWhoA"), whoB = $("lpWhoB");
    var T = window.HB_TR || function (x) { return x; };
    function draw() {
      var a;
      if (mode === "equal") { a = total / 2; sl.disabled = true; slLbl.textContent = T("Each of you covers"); slVal.textContent = T("half"); }
      else if (mode === "percent") { a = total * sl.value / 100; sl.disabled = false; sl.max = 100; slLbl.textContent = T("Alex covers"); slVal.textContent = sl.value + "%"; }
      else { a = total - sl.value; sl.disabled = false; sl.max = total; slLbl.textContent = T("Jordan owes"); slVal.textContent = fmt(+sl.value); }
      var b = total - a, pa = Math.round(a / total * 100);
      barA.style.width = pa + "%"; barB.style.width = (100 - pa) + "%";
      barA.textContent = pa > 14 ? fmt(a) : ""; barB.textContent = 100 - pa > 14 ? fmt(b) : "";
      whoA.textContent = T("covers") + " " + fmt(a); whoB.textContent = b > 0 ? T("owes") + " " + fmt(b) : T("owes nothing");
    }
    lp.querySelectorAll(".lp-modes button").forEach(function (btn) {
      btn.addEventListener("click", function () {
        mode = btn.dataset.mode;
        lp.querySelectorAll(".lp-modes button").forEach(function (x) { x.setAttribute("aria-pressed", x === btn ? "true" : "false"); });
        sl.value = mode === "owed" ? 30 : 50; draw();
      });
    });
    sl.addEventListener("input", draw);
    draw();
  }

  // scroll reveals: everything starts visible; only hide what is below the fold and can be revealed
  if ("IntersectionObserver" in window && !reduce) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.remove("pre"); io.unobserve(en.target); } });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    var armed = false;
    function arm() {
      if (armed || lp.hidden) return; armed = true;
      lp.querySelectorAll(".lp-rv").forEach(function (el, i) {
        if (el.getBoundingClientRect().top > innerHeight) { el.classList.add("pre"); el.style.transitionDelay = ((i % 3) * 70) + "ms"; io.observe(el); }
      });
    }
    arm();
    new MutationObserver(arm).observe(lp, { attributes: true, attributeFilter: ["hidden"] });
  }
})();
