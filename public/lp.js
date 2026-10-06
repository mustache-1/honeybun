// Landing page: live money counter, split demo, and scroll reveals. Loaded on every page but only touches #scr-landing.
(function () {
  var lp = document.getElementById("scr-landing");
  if (!lp) return;
  var reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var fmt = function (n) { return "$" + Math.abs(n).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }); };
  var $ = function (id) { return document.getElementById(id); };

  // hero: the money card counts up the first time it's on screen
  var amt = $("lpAmt"), s1 = $("lpS1"), s2 = $("lpS2"), s3 = $("lpS3"), meter = $("lpMeter"), started = false;
  function setAmt(v) { var s = fmt(v).split("."); amt.innerHTML = s[0] + "<small>." + s[1] + "</small>"; }
  function count() {
    if (started) return; started = true;
    var t0 = performance.now(), dur = reduce ? 0 : 1800, ease = function (t) { return 1 - Math.pow(1 - t, 3); };
    function frame(now) {
      var p = dur ? Math.min(1, (now - t0) / dur) : 1, e = ease(p);
      setAmt(1912.37 * e); s1.textContent = fmt(4500 * e); s2.textContent = fmt(2587.63 * e); s3.textContent = fmt(132 * e);
      if (p < 1) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
    setTimeout(function () { meter.style.width = "62%"; }, 200);
  }
  if (amt) {
    if ("IntersectionObserver" in window) {
      var io0 = new IntersectionObserver(function (en) { if (en[0].isIntersecting) { count(); io0.disconnect(); } });
      io0.observe(amt);
    } else count();
  }

  // hop calendar demos (the feature tile animates, the laptop screen is still)
  var SPEND = [0, 42, 18, 0, 95, 140, 60, 12, 0, 0, 30, 22, 0, 75, 38, 0, 50, 26, 0, 212, 88, 15, 0, 44, 20, 0, 70, 0, 33, 0];
  var sorted = SPEND.filter(function (v) { return v > 0; }).sort(function (x, y) { return x - y; });
  function fillCal(el, animate) {
    if (!el) return;
    var html = "<span class='off'></span>"; // September 2026 starts on a Tuesday
    SPEND.forEach(function (v, i) {
      var r = v ? (sorted.indexOf(v) / (sorted.length - 1)).toFixed(2) : 0;
      html += "<span class='" + (v ? "" : "paw") + "' style='--r:" + r + (animate ? ";--t:" + (i * 0.12).toFixed(2) + "s" : "") + "'></span>";
    });
    for (var k = SPEND.length + 1; k < 35; k++) html += "<span class='off'></span>";
    el.innerHTML = html;
  }
  fillCal($("hbCal"), true); fillCal($("hbMiniCal"), false);

  // hero parallax: floating cards drift a little with the mouse
  var stage = $("hbStage");
  if (stage && !reduce && matchMedia("(pointer: fine)").matches) {
    stage.querySelectorAll("[data-depth]").forEach(function (el) { el.style.setProperty("--d", el.getAttribute("data-depth")); });
    var hero = lp.querySelector(".hb-hero"), raf = 0;
    hero.addEventListener("mousemove", function (e) {
      if (raf) return;
      raf = requestAnimationFrame(function () {
        raf = 0;
        var r = stage.getBoundingClientRect();
        stage.style.setProperty("--mx", Math.max(-0.6, Math.min(0.6, (e.clientX - (r.left + r.width / 2)) / r.width)).toFixed(3));
        stage.style.setProperty("--my", Math.max(-0.6, Math.min(0.6, (e.clientY - (r.top + r.height / 2)) / r.height)).toFixed(3));
      });
    });
    hero.addEventListener("mouseleave", function () { stage.style.setProperty("--mx", 0); stage.style.setProperty("--my", 0); });
  }

  // updates tab: a changelog kept in this file, newest first
  var TAGS = { new: "New", improved: "Improved", fixed: "Fixed", design: "Design", security: "Security" };
  var COLOR = { new: "var(--c-green)", improved: "var(--c-blue)", fixed: "var(--c-rose)", design: "var(--c-lilac)", security: "var(--c-honey)" };
  var ICON = {
    landing: '<path d="M3 11l9-7 9 7v9H3z"/><path d="M10 20v-5h4v5"/>', bug: '<path d="M8 9V7a4 4 0 0 1 8 0v2M5 13h14M12 9v12M6 21c0-4 2-7 6-7s6 3 6 7"/>',
    key: '<circle cx="9" cy="8" r="3.5"/><path d="M3 20c.8-3.6 3.2-5.5 6-5.5 1.3 0 2.5.4 3.5 1.1"/><circle cx="17" cy="13" r="2.5"/><path d="M17 15.5V21l1.5-1.2M17 18l-1.5-1"/>',
    bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>', sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    budget: '<rect x="4" y="5" width="16" height="15" rx="3"/><path d="M4 10h16M9 3v4M15 3v4"/>', search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
    undo: '<path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>', tap: '<path d="M13 3L5 14h6l-1 7 9-11h-6z"/>', repeat: '<path d="M17 2l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14M7 22l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>'
  };
  var LOG = [
    { v: "3.0", date: "2026-10-04", name: "Honeybun 3.0", items: [
      { t: "Honeybun for iPhone is here", d: "A real iPhone app. It opens straight to your budget with a native tab bar, pull to refresh, swipe back, a Face ID lock, and small taps when you add or delete. The app icon even puts on a witch hat for Halloween.", tags: ["new"], icon: "landing" },
      { t: "Notifications that make a sound", d: "Your phone now gets a push notification, with a sound, when your partner adds something to your joint account, when a bill is due, and when Bun has news. It asks once when you open the app.", tags: ["new"], icon: "bell" },
      { t: "Swipe, pull and tap", d: "Swipe a spending row right to edit it or left to delete it, pull down to refresh, and the Add screen opens on the category you used last.", tags: ["new"], icon: "tap" },
      { t: "Join with a code, made easy", d: "On the start screen the invite code box now comes first. If you already made your own budget, Settings has Join with a code, which moves you into your partner's budget.", tags: ["improved"], icon: "key" },
      { t: "Joint accounts keep it all in one pot", d: "Entries can't be private on a joint account any more, so your balance, forecast and carry-over always include everything. Your partner hears about it when you add something.", tags: ["improved"], icon: "budget" },
      { t: "The app updates itself", d: "No more Refresh button. When a new version is out, the iPhone app quietly updates in the background the next time you open it.", tags: ["improved"], icon: "landing" },
      { t: "A cleaner iPhone app", d: "No scroll bar down the side, no install steps or theme settings you don't need, and your streak, level and gift card now live in Bun's inbox.", tags: ["design"], icon: "landing" },
      { t: "A smarter forecast", d: "The month-end forecast waits for a week of spending, counts a big one-off purchase once, and shows how it got its number: what is left now, paychecks, bills and everyday spending.", tags: ["improved"], icon: "budget" },
      { t: "Bun's tips come as notifications", d: "Bun's tip card and the status line on Home are gone. Instead, Bun sends you a helpful tip as a notification every few days, with your own numbers when there's something worth pointing out.", tags: ["new", "design"], icon: "bell" },
      { t: "New buddies", d: "Pick from 12 new buddies: Bun in a honey pot as a cowboy, witch, ghost, angel, devil, frog, dinosaur and more. Your current buddy turns into its new look automatically. The color picker is gone, since the pictures bring their own look.", tags: ["new", "design"], icon: "sun" },
      { t: "Halloween Honeybun fits every phone", d: "Halloween mode now adapts to any screen size and the iPhone safe areas. Coming up shows your real bills and payments and you can edit them, goals get fitting icons, and the shopping list is plain and fully editable.", tags: ["new", "fix"], icon: "sun" },
      { t: "A new Honeybun icon", d: "Bun is now peeking out of a honey pot, on the website, the iPhone app and the Windows app. During Halloween, Bun wears a witch hat in a spooky cauldron.", tags: ["new", "design"], icon: "sun" },
      { t: "A homepage built around the app", d: "The homepage now leads with the App Store and real screenshots of the app. The Windows app is still there for anyone who has it.", tags: ["design"], icon: "landing" },
      { t: "Widgets and Siri can sign in", d: "The home-screen widget and Siri shortcuts now share your sign-in with the app, so they can show what is left.", tags: ["fixed"], icon: "bug" },
      { t: "Plan calendar fixed", d: "On phones the day numbers were drawn above their boxes. They sit where they belong now.", tags: ["fixed"], icon: "bug" }
    ] },
    { v: "2.0", date: "2026-09-30", name: "Honeybun 2.0", items: [
      { t: "Honeybun goes spooky", d: "A glowing moon, flapping bats, dangling spiders, cobwebs, drifting fog and a little graveyard now light up the homepage and the app, with warm orange buttons and Bun in a witch hat. It's on from Sept 29 through October and switches itself off after.", tags: ["new", "design"], icon: "sun" },
      { t: "Honeybun for Windows", d: "Download Honeybun for Windows and keep it on your taskbar, with the same account as your phone and the web. It shows a red dot when Bun has something new, and Bun can wait in your tray with no window open.", tags: ["new"], icon: "landing" },
      { t: "It updates itself", d: "The Windows app checks for a newer version when it opens and every few hours, shows the progress under Bun, then installs it and reopens. There's also a Check for updates button in the side menu.", tags: ["new"], icon: "landing" },
      { t: "A brand new homepage", d: "A fresh look with a hopping Bun, live mini demos of every feature, a hop calendar preview, and a Download section for Windows and phones. You can also install Honeybun from Chrome or Edge in one click.", tags: ["new", "design"], icon: "landing" },
      { t: "Bun's tip of the day", d: "A new card on Home with a tip from Bun, based on your month: a budget running low, habits that add up, subscriptions, no-spend days, savings goals and your streak.", tags: ["new"], icon: "bell" },
      { t: "Subscriptions in Plan", d: "Bills & paydays has a Subscriptions tab with every subscription, its next charge, what it costs you a month and a year, and a button to add one.", tags: ["new"], icon: "budget" },
      { t: "Honeybun for iPhone", d: "A native iPhone app with a Face ID lock, home-screen and lock-screen widgets that show what is left this month, real push notifications, and Siri shortcuts like Hey Siri, log an expense in Honeybun.", tags: ["new"], icon: "landing" },
      { t: "Easier sign-up", d: "Sign up with just a username (no email needed), or with Face ID or a passkey. Without an email you get a recovery code to save, so you can still reset your password. Your existing email login works exactly as before.", tags: ["new"], icon: "landing" },
      { t: "Month-end forecast", d: "A card in Stats (and a line on Home) guesses where the month is heading, with a chart, a what-if for saving a little each day, and how you compare with last month.", tags: ["new"], icon: "budget" },
      { t: "Your own categories", d: "Make categories with your own name and emoji, like Dog treats. Add one from the Add screen or manage them under Budget in Plan, and they work in budgets, stats and alerts.", tags: ["new"], icon: "budget" },
      { t: "Shared shopping list", d: "Add what you need, tick it off in the store and see your partner's changes within seconds. When you're done, log what you paid as groceries in one tap, split like any shared expense. Find it on Together, or on Home when the list has something on it.", tags: ["new"], icon: "budget" },
      { t: "Carry over last month's balance", d: "On the first of every month Honeybun asks if you want to carry last month's leftover (or shortfall) into the new month, by notification and when you open Home. Say yes and it shows on Home as Carried over from last month and counts in your balance. Your partner sees the same answer. You can change your mind with Change on Home, and pick Always carry or Start fresh in Settings so it stops asking.", tags: ["new"], icon: "budget" },
      { t: "Bun gets sleepy", d: "If nothing has been logged for 3 days, Bun looks sleepy on Home and asks you to log something. Log anything and Bun perks right up.", tags: ["new"], icon: "bell" },
      { t: "Heads-up alerts", d: "A Heads up from Bun card on Home warns you when a category budget is at 80% or over, with what you can spend per day for the rest of the month, and tells you when a subscription's price goes up or down.", tags: ["new"], icon: "bell" },
      { t: "Joint accounts", d: "Couples who share one bank account can turn on Joint account in Settings and everything adds up together: Together shows one pot with what came in, what was spent and what is left, nobody owes anybody, and expenses are not split.", tags: ["new"], icon: "landing" },
      { t: "Fair share for couples", d: "A new tab for partners: who brought in how much, who has spent how much, and a little brainstorm tool to try splitting shared costs 50/50, by income, or with your own slider.", tags: ["new"], icon: "landing" },
      { t: "Lighter on your computer", d: "The Windows app now pauses its animations and refreshing whenever the window is in the background or hidden in the tray, resizing is smoother, and slower computers switch to a lite look on their own.", tags: ["improved"], icon: "landing" },
      { t: "Tidier Home and Plan", d: "Coming up, Debts, Bills and Subscriptions show a page at a time, so nothing needs to scroll on desktop.", tags: ["improved"], icon: "budget" },
      { t: "Fixes", d: "Email reminders stay on after you confirm your email, the homepage cards no longer overlap on phones, and Bun skips habit tips about the catch-all Other category.", tags: ["fixed"], icon: "bell" }
    ] },
    { v: "1.7", date: "2026-09-29", name: "New Stats and one-screen desktop", items: [
      { t: "Hop calendar", d: "Stats now opens on a calendar of your month. Bigger dots mean bigger spending days, and paw prints mark days you spent nothing. See your no-spend days, calmest week, and biggest day at a glance.", tags: ["new", "design"], icon: "landing" },
      { t: "Where it went, by month or year", d: "One card with a Month and Year switch, plus a one-line 50/30/20 check. Your year chart and badges open in their own windows.", tags: ["improved"], icon: "landing" },
      { t: "Desktop fits your screen, top to bottom", d: "Every tab now fits on one screen without scrolling, from small laptops to 1920×1080 monitors. Settings sits in three tidy columns and Plan in three.", tags: ["improved", "design"], icon: "landing" }
    ] },
    { v: "1.6", date: "2026-09-28", name: "Referral rewards", items: [
      { t: "Invite friends, earn gift cards", d: "Share your personal link. For every 10 friends who use Honeybun for a week, you get a $10 gift card. Find it on Home, in Settings, or in the sidebar.", tags: ["new"], icon: "bell" },
      { t: "Ask Bun about your referrals", d: "Tap Referrals in Bun's inbox and Bun tells you who signed up, who counts, and how close you are to your next gift card.", tags: ["new"], icon: "bell" },
      { t: "Pages for your monthly list", d: "Everything this month and search results show 8 at a time with page buttons underneath, so the Together screen stays short.", tags: ["improved"], icon: "landing" }
    ] },
    { v: "1.5", date: "2026-09-28", name: "Desktop polish and fit to screen", items: [
      { t: "Desktop fits your screen", d: "The wide layout now scales to your monitor, so a big screen sees the same composition, just larger. Sidebar gets Bun's inbox, Help, Settings, and your household at the bottom.", tags: ["improved", "design"], icon: "landing" },
      { t: "Home and Stats rearranged on desktop", d: "Home shows Bills, Bun's note, and Honey jars in the right column with a fourth Month left stat. Stats puts your level and numbers in one row, with Where it went beside the year chart.", tags: ["design"], icon: "landing" },
      { t: "Latest fills the Home column on desktop", d: "Home shows ten recent entries on desktop, five per column, so the space under the list is used.", tags: ["improved"], icon: "landing" },
      { t: "Plan matches the design on desktop", d: "Compact calendar with a legend, a dashed Add a bill button, dashed New jar tile, and one-line empty states. Calendar numbers sit inside their cells again.", tags: ["fixed", "design"], icon: "budget" }
    ] },
    { v: "1.4", date: "2026-09-28", name: "A real desktop layout", items: [
      { t: "Desktop layout", d: "On laptops and desktops the app now has a left sidebar instead of the bottom bar, and every screen uses a proper multi-column layout: Plan shows budget, calendar, and bills side by side, Stats puts the charts next to your progress, Together gives the balance its own column. Phones are unchanged.", tags: ["design", "improved"], icon: "landing" },
      { t: "Updates grouped by release", d: "This page now folds each release into one row you can open, so it stays short as the list grows.", tags: ["improved"], icon: "landing" }
    ] },
    { v: "1.3", date: "2026-09-28", name: "Passkeys, push, and a new front door", items: [
      { t: "New landing page", d: "A fresh front door in the app's own colors: a live money card with Bun's ears, a split slider you can drag, and the tap-to-pay scene. Works in light and dark, in three languages.", tags: ["design"], icon: "landing" },
      { t: "Updates tab", d: "This page. Everything we ship shows up here, newest first.", tags: ["new"], icon: "landing" },
      { t: "Bun's inbox opened to an error", d: "Opening the inbox showed \"Something went wrong\" after the budget rollover update. Fixed within the hour.", tags: ["fixed"], icon: "bug" },
      { t: "Passkeys", d: "Log in with Face ID, Touch ID, or your phone's unlock instead of a password. Add one per device in Settings. Passkeys can't be phished or guessed.", tags: ["new", "security"], icon: "key" },
      { t: "Push notifications", d: "Turn on push in Settings and get a nudge when a bill is due, your streak is about to break, or your partner adds a shared expense. On iPhone, add Honeybun to your Home Screen first.", tags: ["new"], icon: "bell" },
      { t: "Light, dark, or auto", d: "A new Appearance setting. Auto follows your device. The whole app, including this page, has a proper light palette now.", tags: ["new", "design"], icon: "sun" },
      { t: "Budget rollover", d: "Turn it on in the budgets dialog and whatever you don't spend carries into next month, starting the month you switch it on.", tags: ["new"], icon: "budget" },
      { t: "Search by amount and date", d: "Tap More next to the search filters to narrow by an amount range or a date range.", tags: ["improved"], icon: "search" },
      { t: "Undo after adding", d: "Every add, including one-tap repeats, shows an Undo button for a few seconds.", tags: ["improved"], icon: "undo" },
      { t: "Apple Pay auto-logging", d: "Make a key in Settings and an iPhone Shortcut logs every tap-to-pay purchase for you. Category guessed from the store, split remembered from last time. No bank connection.", tags: ["new"], icon: "tap" },
      { t: "One-tap repeats", d: "Your five most common expenses sit at the top of the Add screen. Tap one and it's logged with the same amount, category, and split as last time.", tags: ["new"], icon: "repeat" }
    ] }
  ];
  // Website release history includes preview progress; native generated content is unchanged.
  var WEBSITE_UPDATES = [
  {
    "v": "website-2026-10-06",
    "date": "2026-10-06",
    "name": "One Cozy Night Honeybun website",
    "items": [
      {
        "t": "One scene, one homepage",
        "d": "The homepage is now one Cozy Night scene, with the existing witch Bun, sleeping companion, moon, town, lantern and welcome sign. The long marketing page and phone placeholders are gone.",
        "tags": [
          "design"
        ],
        "icon": "landing"
      },
      {
        "t": "The original artwork stays",
        "d": "The single-scene homepage uses the original illustration without redrawing, enhancing or upscaling it. Its native resolution can still look softer on high-density displays.",
        "tags": [
          "design"
        ],
        "icon": "sun"
      },
      {
        "t": "A homepage that stays in place",
        "d": "The homepage is locked to the visible browser height. Detail pages still scroll normally, and mobile spacing adapts to the available height.",
        "tags": [
          "fixed",
          "design"
        ],
        "icon": "landing"
      },
      {
        "t": "Comfortable responsive layouts",
        "d": "Content and navigation reuse the earlier website’s comfortable width and padding. The scene crops responsively without scaling the entire page.",
        "tags": [
          "improved",
          "design"
        ],
        "icon": "landing"
      },
      {
        "t": "Honeybun’s fireflies are back",
        "d": "The original warm drifting fireflies return, with fewer lights on mobile. Motion pauses in the background; Reduced Motion keeps the scene calm.",
        "tags": [
          "design"
        ],
        "icon": "sun"
      },
      {
        "t": "Bun blinks, the companion sleeps",
        "d": "Witch Bun has an occasional blink. The sleeping companion has a gentle breathing motion and a faint sleep trail. Reduced Motion keeps them still.",
        "tags": [
          "design"
        ],
        "icon": "sun"
      },
      {
        "t": "Features, Together and Meet Bun",
        "d": "All three tabs have their own views, with richer cards, existing illustration, warmer lighting and subtle motion. Meet Bun is now in the top navigation.",
        "tags": [
          "new",
          "design"
        ],
        "icon": "landing"
      },
      {
        "t": "Help and Updates stay close",
        "d": "Help, Updates, privacy, terms, support and the language picker remain available. Selecting the Honeybun brand returns to the homepage.",
        "tags": [
          "improved"
        ],
        "icon": "landing"
      },
      {
        "t": "Stay on the homepage after refresh",
        "d": "Opening or refreshing the public homepage no longer sends returning browser visitors straight to sign-in. Existing account and deep-link routes remain available.",
        "tags": [
          "fixed"
        ],
        "icon": "bug"
      },
      {
        "t": "Cleaner artwork boundaries",
        "d": "Section-sized overlays that produced visible edges were removed. The homepage has one environmental image rather than repeated scenery below it.",
        "tags": [
          "fixed",
          "design"
        ],
        "icon": "sun"
      },
      {
        "t": "An honest App Store button",
        "d": "The iPhone app’s public App Store listing is still pending. Download buttons are marked coming soon rather than linking to an invented or unrelated app.",
        "tags": [
          "improved"
        ],
        "icon": "landing"
      }
    ],
    "label": "Website"
  },
  {
    "v": "iphone-preview-phase-7",
    "date": "2026-10-05",
    "name": "Smarter Honeybun · Phase 7 preview",
    "items": [
      {
        "t": "One shared insight engine",
        "d": "Bun’s observations use calculations on the information you enter. Home, planning, goals, debts and shared spending draw from one consistent insight engine.",
        "tags": [
          "new"
        ],
        "icon": "bell"
      },
      {
        "t": "A factual Safe to Spend explanation",
        "d": "A short line explains Safe to Spend and upcoming obligations. Safe to Spend remains income minus spending plus carry-over; upcoming bills are shown separately.",
        "tags": [
          "improved"
        ],
        "icon": "budget"
      },
      {
        "t": "From Bun, with the important notes first",
        "d": "Home prioritizes a small set of relevant observations, avoids filling the card with the same topic, and includes good news when there is something positive to show.",
        "tags": [
          "new",
          "design"
        ],
        "icon": "bell"
      },
      {
        "t": "Why am I seeing this?",
        "d": "Open an observation for friendly explanations and the numbers behind it. More from Bun stays inside the From Bun card; notes can be dismissed for their relevant period.",
        "tags": [
          "new"
        ],
        "icon": "search"
      },
      {
        "t": "Spending pace and comparisons",
        "d": "Bun can notice a budget moving faster than the month, unusual recent spending, and meaningful changes from the same point last month when there is enough history.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Bills and recurring costs",
        "d": "Observations can highlight bills before payday, busy bill days and increases in recurring costs, based on the entries and schedules you have recorded.",
        "tags": [
          "new"
        ],
        "icon": "repeat"
      },
      {
        "t": "Forecasts with clearer context",
        "d": "Monthly planning adds everyday category context and, where the calculation supports it, a realistic weekly spending adjustment. Forecasts remain estimates.",
        "tags": [
          "improved"
        ],
        "icon": "budget"
      },
      {
        "t": "Debt progress and goal milestones",
        "d": "Bun can surface a payment that changes the estimated debt-free month, useful payoff comparisons, goal milestones, contribution pace and completed goals.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Shared planning stays about shared information",
        "d": "Together observations use shared, non-private entries and shared bills. Insight dismissals and display history stay on the device and clear when signing out or changing household.",
        "tags": [
          "improved"
        ],
        "icon": "key"
      },
      {
        "t": "Day Streak moves to Bun’s Inbox",
        "d": "The streak card now lives near the top of the Inbox and opens Stats. Home has more space for money and From Bun; streak calculations are unchanged.",
        "tags": [
          "design"
        ],
        "icon": "bell"
      }
    ],
    "label": "Phase 7"
  },
  {
    "v": "iphone-preview-phase-6",
    "date": "2026-10-05",
    "name": "Debt Center+ · Phase 6 preview",
    "items": [
      {
        "t": "A dedicated Debt Center+",
        "d": "Open Debt Center from Plan to see your recorded debts, paid-down progress, estimated payoff journey and a month-by-month balance path.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Snowball beside Avalanche",
        "d": "Compare the two payoff strategies using the same recorded debts and calculation engine, including estimated interest and time differences.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "What if I paid more?",
        "d": "Explore an extra monthly payment and see its estimated effect on interest and the debt-free date. Honeybun does not make payments or move money.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Paying it down together",
        "d": "Household debt summaries include per-member payment contributions rather than relying only on a short recent-payment list.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "More reliable debt progress",
        "d": "Progress counts an overpaid debt only up to the amount originally owed. Payoff summaries and household calculations have dedicated checks.",
        "tags": [
          "fixed"
        ],
        "icon": "bug"
      }
    ],
    "label": "Phase 6"
  },
  {
    "v": "iphone-preview-release-preparation",
    "date": "2026-10-05",
    "name": "iPhone preview · Release preparation",
    "items": [
      {
        "t": "A native app lifecycle",
        "d": "The app uses the native scene lifecycle and a native SwiftUI root, with the Classic interface retained as a fallback.",
        "tags": [
          "improved"
        ],
        "icon": "landing"
      },
      {
        "t": "More reliable project builds",
        "d": "Shared project and workspace setup now includes the native screens consistently. The minimum supported iOS version is 15.",
        "tags": [
          "improved"
        ],
        "icon": "landing"
      },
      {
        "t": "Checks before an archive",
        "d": "Project validation, release compilation and archive checks help catch missing native screens, assets and lifecycle configuration before a release build.",
        "tags": [
          "improved"
        ],
        "icon": "bug"
      },
      {
        "t": "Privacy declarations and clearer boundaries",
        "d": "Required privacy manifests and safeguards against exposing internal insight diagnostics are included in the app preparation work. This does not mean App Review is complete.",
        "tags": [
          "improved"
        ],
        "icon": "key"
      },
      {
        "t": "Still preparing for the App Store",
        "d": "Native functionality through Phase 7 is preview development. A TestFlight release candidate, physical iPhone QA, the Apple-requested recording and App Review submission remain ahead.",
        "tags": [
          "improved"
        ],
        "icon": "landing"
      }
    ],
    "label": "Build"
  },
  {
    "v": "iphone-preview-phases-1-5",
    "date": "2026-10-05",
    "name": "Native Honeybun · Phases 1–5 preview",
    "items": [
      {
        "t": "Native Home, Money and entry forms",
        "d": "Home, Money, recorded transactions and add/edit/delete forms use native screens backed by Honeybun’s existing data. Coming Up shows recorded bills and payments.",
        "tags": [
          "new",
          "design"
        ],
        "icon": "landing"
      },
      {
        "t": "A clearer launch and safer screen spacing",
        "d": "The native Halloween launch artwork, status-bar treatment and tab-bar layout were refined. Scrolling screens reserve space so the final content stays reachable above navigation.",
        "tags": [
          "improved",
          "design"
        ],
        "icon": "landing"
      },
      {
        "t": "Goals from start to finish",
        "d": "Native Goals includes active and completed views, goal details, deposits, withdrawals, history undo, and creating, editing and deleting goals with illustrated icons.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "A native Together screen",
        "d": "Household balances, fair-share details, settlement, payments, member controls, shopping and entry search have native views and sheets for supported household modes.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "The shared shopping list",
        "d": "Manage, rename and check off shopping items, and open an expense form from shopping when recording what you paid.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "A real Bun Inbox",
        "d": "Inbox tabs, unread state and message actions route to the relevant native screens. Bill-paid and carry-over actions are connected to existing account data.",
        "tags": [
          "new"
        ],
        "icon": "bell"
      },
      {
        "t": "Native sign-in and account flows",
        "d": "Welcome, sign-in, account creation, recovery, password reset, email verification, onboarding and account management are native. Sign in with Apple and passkey flows are included.",
        "tags": [
          "new"
        ],
        "icon": "key"
      },
      {
        "t": "Settings and app lock",
        "d": "Native Settings includes profile, supported Face ID app-lock controls, notification settings, sign-out and About. Account and email status remain visible where relevant.",
        "tags": [
          "new"
        ],
        "icon": "key"
      },
      {
        "t": "Plan, budgets and the calendar",
        "d": "Plan brings budgets, the calendar, forecasts, bills, subscriptions and debts into native screens. Quick payday-and-bill setup can be reopened.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Your own categories",
        "d": "Create categories from entry and bill forms and manage the categories used in planning and spending.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Debt payoff planning",
        "d": "The native payoff planner compares Snowball and Avalanche, accepts an extra monthly amount and estimates a debt-free month. Debt Center+ builds on this earlier work.",
        "tags": [
          "new"
        ],
        "icon": "budget"
      },
      {
        "t": "Stats and your progress",
        "d": "Native Stats includes monthly and yearly views, the hop calendar, recap, badges, levels and referrals. Progress and rewards respond to supported app actions.",
        "tags": [
          "new"
        ],
        "icon": "sun"
      },
      {
        "t": "Carry-over you can change",
        "d": "Review or change the current month’s carry-over from the money card and choose a carry-over preference in Settings.",
        "tags": [
          "new"
        ],
        "icon": "repeat"
      },
      {
        "t": "Split choices and private entries",
        "d": "Entry forms retain supported split options, household behavior and private-entry rules. Joint-account entries follow the account’s shared behavior.",
        "tags": [
          "improved"
        ],
        "icon": "budget"
      },
      {
        "t": "Faster everyday entry actions",
        "d": "Undo, one-tap repeats, the last-used category, swipe-to-edit/delete and haptic feedback bring familiar entry shortcuts to the native experience.",
        "tags": [
          "improved"
        ],
        "icon": "tap"
      },
      {
        "t": "Offline entries and safer retries",
        "d": "Entries can queue offline and appear locally before syncing. Retry identifiers help avoid duplicate creation when a saved entry is sent again.",
        "tags": [
          "new"
        ],
        "icon": "repeat"
      },
      {
        "t": "Search that narrows the list",
        "d": "Native search supports person, category, amount and date filters, with relevant edit and delete actions.",
        "tags": [
          "new"
        ],
        "icon": "search"
      },
      {
        "t": "Help, What’s new and Ask Bun",
        "d": "Native Help, generated release notes and Ask Bun in the Inbox are included, along with the existing Apple Pay shortcut-key and tip-jar interfaces.",
        "tags": [
          "new"
        ],
        "icon": "bell"
      },
      {
        "t": "Widget and Siri session handling",
        "d": "The native app manages the shared widget/Siri token on sign-in and revokes it on sign-out.",
        "tags": [
          "improved"
        ],
        "icon": "key"
      },
      {
        "t": "Referral and notification follow-through",
        "d": "Referral links and native sign-ups carry attribution; device notification registration follows the active session. Household join/leave and related notification cleanup were refined.",
        "tags": [
          "improved"
        ],
        "icon": "bell"
      }
    ],
    "label": "Phases 1–5"
  }
];
  LOG = WEBSITE_UPDATES.concat(LOG.map(function (release) {
    var copy = Object.assign({}, release, { items: release.items.map(function (entry) {
      var e = Object.assign({}, entry, { tags: entry.tags.map(function (tag) { return tag === "fix" ? "fixed" : tag; }) });
      if (e.t === "Honeybun for iPhone is here") { e.t = "Honeybun for iPhone preview"; e.d = "Earlier iPhone app-shell work introduced native navigation, refresh gestures, app-lock controls, haptics and seasonal icons. This is development history, not a public App Store release."; }
      if (e.t === "A homepage built around the app") e.d = "An earlier homepage direction emphasized the iPhone app and screenshot previews. The current single-scene website replaces that layout; the public App Store listing is still pending.";
      if (e.t === "Passkeys") e.d = "Use supported device authentication, such as Face ID, Touch ID or your phone’s unlock, instead of typing a password. Manage passkeys in Settings.";
      return e;
    }) });
    return copy;
  }));
  var T2 = window.HB_TR || function (x) { return x; };
  var list = $("lpUpdList"), legend = $("lpUpdLegend");
  // the changelog renderer is shared with the app's What's new screen
  function renderUpdates(list, legend) {
    var fmtDate = function (d) { var p = d.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]).toLocaleDateString(undefined, { month: "long", day: "numeric", year: "numeric" }); };
    if (legend) legend.innerHTML = Object.keys(TAGS).map(function (k) { return '<span class="lp-tag ' + k + '"><i></i>' + T2(TAGS[k]) + '</span>'; }).join("");
    var tile = { new: "t-green", improved: "t-blue", fixed: "t-rose", design: "t-lilac", security: "t-honey" };
    list.innerHTML = LOG.map(function (day, di) {
      var counts = {}; day.items.forEach(function (it) { it.tags.forEach(function (k) { counts[k] = (counts[k] || 0) + 1; }); });
      return '<details class="lp-rel"' + (di === 0 ? ' open' : '') + '><summary><span class="lp-rel-v">' + T2(day.label || ('v' + day.v)) + '</span><span class="lp-rel-main"><b></b><small>' + fmtDate(day.date) + ' · ' + day.items.length + ' ' + T2(day.items.length === 1 ? "update" : "updates") + '</small></span><span class="lp-rel-tags">' +
        Object.keys(counts).map(function (k) { return '<span class="lp-tag ' + k + '"><i></i>' + counts[k] + '</span>'; }).join("") + '</span><svg class="lp-rel-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg></summary><div class="lp-upd-cards">' +
        day.items.map(function (it) {
          var main = it.tags[0];
          return '<article class="lp-upd" style="--upd:' + COLOR[main] + '"><span class="lp-ic ' + tile[main] + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICON[it.icon] + '</svg></span><div class="body"><b></b><p></p><div class="tags">' +
            it.tags.map(function (k) { return '<span class="lp-tag ' + k + '"><i></i>' + T2(TAGS[k]) + '</span>'; }).join("") + '</div></div></article>';
        }).join("") + '</div></details>';
    }).join("");
    list.querySelectorAll(".lp-rel").forEach(function (el, di) { el.querySelector(".lp-rel-main b").textContent = T2(LOG[di].name); });
    var i = 0; LOG.forEach(function (day) { day.items.forEach(function (it) { var el = list.querySelectorAll(".lp-upd")[i++]; el.querySelector("b").textContent = T2(it.t); el.querySelector("p").textContent = T2(it.d); }); });
  }
  window.HB_UPDATES = { log: LOG, render: renderUpdates };
  if (list) {
    renderUpdates(list, legend);
    var badge = $("lpUpdCount"); badge.textContent = LOG[0].items.length; badge.classList.add("on");
    function showRewards(on) {
      var sec = $("lp-rewards"); if (!sec) return;
      if (on) { $("lp-updates").hidden = true; lp.setAttribute("data-view", "rewards"); } else if (lp.getAttribute("data-view") === "rewards") lp.removeAttribute("data-view");
      sec.hidden = !on;
      if (on) window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
    }
    if ($("lpRewardsLink")) {
      $("lpRewardsLink").addEventListener("click", function (e) { e.preventDefault(); showRewards(true); });
      $("lpRwBack").addEventListener("click", function () { showRewards(false); window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" }); });
      if (location.hash === "#lp-rewards") showRewards(true);
    }
    function showUpdates(on) {
      if (on) $("lp-rewards").hidden = true;
      if (on) lp.setAttribute("data-view", "updates"); else lp.removeAttribute("data-view");
      $("lp-updates").hidden = !on;
      window.scrollTo({ top: 0, behavior: reduce ? "auto" : "smooth" });
    }
    $("lpUpdatesLink").addEventListener("click", function (e) { e.preventDefault(); showRewards(false); showUpdates(true); });
    lp.querySelectorAll("[data-updates-go]").forEach(function (b) { b.addEventListener("click", function (e) { e.preventDefault(); e.stopPropagation(); showRewards(false); showUpdates(true); }); });
    lp.querySelectorAll("[data-rewards-go]").forEach(function (b) { b.addEventListener("click", function (e) { e.preventDefault(); showRewards(true); }); });
    $("lpUpdBack").addEventListener("click", function () { showUpdates(false); });
    lp.querySelectorAll(".lp-links a:not(#lpUpdatesLink):not(#lpRewardsLink), .lp-brand").forEach(function (a) { a.addEventListener("click", function () { if (lp.getAttribute("data-view") === "updates") showUpdates(false); if (lp.getAttribute("data-view") === "rewards") showRewards(false); }); });
  }

  // scroll reveals: sections rise in as they come into view (everything stays visible if this can't run)
  if ("IntersectionObserver" in window && !reduce) {
    lp.classList.add("rv-on");
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } });
    }, { rootMargin: "0px 0px -6% 0px", threshold: 0.06 });
    lp.querySelectorAll(".rv").forEach(function (el) { io.observe(el); });
  }
})();
