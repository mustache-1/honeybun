# Honeybun 1.0 reference landing preview

Work is local on `claude/wizardly-ritchie-b9p7jn` only. No merge, push, deployment, TestFlight upload or Apple submission.

## Visual implementation

The current rebuild follows the user's approved 1024 × 1536 composition: hero and navigation, Home/Safe to Spend, From Bun, three Plan/Debt/Goals cards, Together, four-item trust strip and final orange CTA. Copy is transcribed from that reference. Exact reference crops supply Bun, the sleeping companion, sign, peeking Buns, couple, icons, phone concept previews and App Store buttons. Cleaned scenery fills the previously obscured areas; visible artwork is original reference artwork. HTML/CSS headings, copy, navigation, cards and screenshot slots stay independent and responsive. This is not the concept PNG used as a giant webpage background.

Desktop proportions scale with the container. Phones stack on narrow screens. Gentle honey glow, drifting ember, hover movement and scroll reveals respect reduced motion. Existing legal, support, account access, language selector, Updates and rewards remain in a compact disclosure after the reference design.

Phone crops currently show the approved concept and are explicitly labeled. They are not final native screenshots. All six are replaceable through `public/landing.js`. Exact capture instructions are in `public/native-shots/README.md`. App Store buttons preserve the requested artwork but stay on the local landing page; the verified live listing is still unavailable (`APPSTORE_URL` remains empty). Do not publish until real captures and the listing are ready.

## Files changed by this revision

- public/index.html — reference composition, exact copy, retained app/account DOM and legacy marketing sections.
- public/landing.css — proportional desktop layout, mobile stacking, isolated marketing styles, subtle motion.
- public/landing.js — six native image slots, reveal motion, footer disclosure and anchors.
- public/landing-art/reference/ — separate exact reference crops and cleaned scenic background.
- public/landing-art/README.md — asset provenance.
- public/native-shots/README.md — exact capture list and replacement instructions.
- WEBSITE_PREVIEW.md — current report and preview instructions.

## Checks

JavaScript syntax and git whitespace checks pass. Browser review at 1024, 1920, 390 and 320 px: no horizontal overflow; artwork loads. Updates/back, rewards/back, footer disclosure and sign-in entry checked. No browser console errors observed. Local root, landing CSS/JS, privacy, terms, Apple association, reset/join routes respond 200; unauthenticated API responds 401 as expected. App/account HTML following the landing section is identical to original `be890f4` apart from the marketing script. Native app, app.js, backend, Cloudflare config and legal files are unchanged from that original checkpoint.

Final native screenshots, production authentication, physical-device QA, translations of new marketing copy and live App Store listing remain outside this local visual review. Reconstruction of scenery covered by the original text/phones cannot be pixel-identical; exact supplied characters and buttons are retained.

## Exact preview instructions

The preview is running at http://127.0.0.1:8787/. Reload this page. Use a signed-out/private browser if the account app opens instead.

To restart:

```bash
cd /Users/rodrigoavila/Documents/GitHub/honeybun
git branch --show-current
XDG_CONFIG_HOME=/private/tmp/honeybun-preview-config WRANGLER_LOG_PATH=/private/tmp/honeybun-preview.log npm run dev -- --local --ip 127.0.0.1 --port 8787
```

If dependencies are missing, run `npm ci` first. If assets change, stop the server with Ctrl-C and restart it because this environment disables asset watching. Changes and commits are local; do not pull expecting them to exist remotely. The revision hash is available with `git log -1 --format=%H` and in the accompanying user-facing report.

Website approval → production website deployment → feature/design freeze → TestFlight RC → physical iPhone QA → Apple-requested recording → App Review submission. No next roadmap step started.


## Quality and navigation revision

Header navigation now contains only Updates and the App Store CTA. Updates retains the previous website's existing release-history behavior and count. Sign in, Try the web app, Windows and rewards links were removed from the marketing footer; app/account screens and handlers still exist unchanged.

`public/landing-art/crisp/` supplies scalable SVG feature/trust icons, six vector concept phone previews with crisp lettering and metal frames, a continuous 2048 × 768 restored hero, and transparent higher-detail Bun illustrations. Phone images recreate the approved concept; they are not final native captures. The disclosure retains that distinction, and six native replacement slots remain available. Orange buttons now use real SVG/HTML lettering. Soft shading, lower device fades and transparent character edges replace the rectangular crop seams.

Motion now includes 44 softly glowing fireflies across the full landing page, breathing honey glow, gentle character floating, card hover glow and scroll reveals. Reduced-motion settings disable animation. Browser checks at 1920, 390 and 320 px passed without overflow or broken imagery; Updates/back checked; no browser errors observed. SVG XML parsing, JavaScript syntax and whitespace checks pass. All app markup after the landing section was compared to e9fea85 and remains unchanged.

Changed in this revision: public/index.html, public/landing.css, public/landing.js, public/landing-art/crisp/, public/landing-art/README.md, public/native-shots/README.md and this report. The preview still runs locally at http://127.0.0.1:8787/. No merge, deployment, native upload or submission.


Additional visual fixes: removed baked-in outlines by switching to the fully cleaned scenic background; removed the Goals peeking mascot and aligned its phone with the other two feature cards; restored the original rounded header mascot through a reference-guided high-resolution transparent edit. Fireflies cover every landing section and do not intercept clicks. The old source crops are no longer served by these components.


## Eyebrow, artwork placement and Updates refinement

The eyebrow now uses the reference's warm-pink wording and a separate small muted heart. From Bun artwork overlaps behind the phone edge to hide the straight cut and align the peek. The background's lower-right lantern was removed through a targeted image edit, leaving the animated couple's lantern as the only lantern beside them. The rest of the scenic background is retained.

Updates has a warm translucent navigation pill with a sparkle and gold count badge. Its view uses the same illustrated purple atmosphere, cream typography, a Bun header, color-coded tags and shaded release cards. Existing release notes, dates, counts and navigation logic remain unchanged. No new release claims were added. Minor concept-phone panel spacing was corrected to eliminate overlapping panels.

Verified at 1920 and 390 px, including Updates/back; at 320 px the navigation items fit without overlap or horizontal overflow. Seven existing release groups remain. No browser console errors; SVG parsing, JavaScript syntax and git whitespace checks pass. Account/app markup after marketing is unchanged from 9267982. Final native captures and App Store URL remain pending. No deployment or next roadmap work.

Files changed this revision: public/index.html, public/landing.css, public/landing-art/crisp/concept-plan.svg, concept-debt.svg, concept-goals.svg, new scene-single-lantern.webp, public/landing-art/README.md and WEBSITE_PREVIEW.md.


## Badges and expanded atmosphere animation

Replaced both plain dotted assurance lines with three compact shaded badges and sharp SVG icons: Free, No bank login and Made for iPhone. The final CTA section has enough room for the badges on desktop and mobile.

The full landing page now has 100 mixed particles on desktop and 60 on phones: drifting fireflies, rising embers, twinkling sparkles and small falling leaves. Added a periodic CTA sheen and pulsing warm character/honey glows. Effects use CSS animation without a continuous JavaScript rendering loop, ignore pointer input and respect reduced-motion preferences. Existing layout, wording and artwork remain in place.

Verified at 1920, 390 and 320 px with no horizontal overflow; all three mobile badges fit on one line. All four particle animation types are active, imagery loads, and no browser console errors were observed. JavaScript syntax and whitespace checks pass; account/app markup after the landing section remains unchanged from 39aebfe.

Changed: public/index.html, public/landing.css, public/landing.js and WEBSITE_PREVIEW.md. The preview remains http://127.0.0.1:8787/. Final native screenshots and the App Store listing URL remain pending. No merge, deployment or native release work performed.


## Meet Bun and Help tabs

Added matching purple navigation pills for Meet Bun and Help alongside Updates. Meet Bun opens an illustrated introduction with three cards describing existing insight and planning behavior. Help opens six expandable answers covering bank connections, Safe to Spend, insights, solo/Together use, money movement and App Store availability, plus the existing support email and legal links.

Navigation works between all three views and returns to the landing page. The two new tabs use keyboard focus indicators and move focus to their page heading when opened. Mobile navigation uses a second row to preserve readable tabs and the download button. No sign-in or additional platform links added.

Checked desktop at 1280 px and phones at 390/320 px: no horizontal overflow, all artwork loads, FAQ expansion works, and Help → Updates → Meet Bun → landing transitions work. No browser console errors observed. JavaScript syntax and whitespace checks pass; app markup after the marketing main is unchanged from e1dfa68.

Changed: public/index.html, public/landing.css, public/landing.js and WEBSITE_PREVIEW.md. Preview: http://127.0.0.1:8787/. Native screenshots and live App Store URL remain pending. No deployment or next-roadmap work performed.


## Approved website deployment and footer cleanup

Removed the closing App Store button and repeated assurance badges; the header and hero CTAs remain. The download anchor now points to the hero. Retained a short scenic fade into the Help and privacy footer.

Scope: website assets only. Do not modify or publish the main iOS app or Phase 6/7 app work. No TestFlight or Apple submission. The existing branch remains claude/wizardly-ritchie-b9p7jn; no merge into main is authorized.

Local desktop check confirms two remaining download CTAs, no duplicate footer block and a valid download anchor; syntax and whitespace checks pass. Cloudflare login is expired. GitHub push is authorized, but production deployment must be verified separately. No website deployment workflow exists in the checked-in GitHub Actions configuration.


Deployment authorization refinement: the user explicitly approved copying website files only to main for Cloudflare's GitHub deployment. Do not merge the working branch. The production commit must preserve main's existing iOS files, backend, Cloudflare configuration, auth/app JavaScript and account markup. Account markup after the marketing section (apart from the additional landing script) and public/app.js were compared to production main 066d61e and match exactly. All edited files are website assets or documentation.


## Responsive sizing and homepage navigation correction

The illustrated page now grows gradually with browser width and caps at 1440 CSS pixels. At 2560 × 1440 it is 1440 px wide, at 1920 it is about 1347 px, and at 1366 it is about 1259 px. Phones use their full width. The layout scales using its own container width, keeping artwork and typography in proportion without magnifying them across a large monitor.

The browser root homepage now opens the marketing landing page before account bootstrap, including visitors with a saved had-account flag or an existing session. Native iOS, desktop app, installed web app, quick actions, invitation links, password reset and email verification retain their existing startup paths. Clicking the Honeybun logo returns to the landing view without reloading.

Changes: public/app.js (browser homepage startup guard only), public/landing.css, public/landing.js and this report. No native iOS, backend, legal, Cloudflare configuration or workflow changes.

Verified actual bootstrap code in nine cases, including returning-account and signed-in browser homepages, native iOS, desktop, installed web app, quick action, join, reset and verify. Browser review at 2560, 1920, 1366, 390 and 320 px found no horizontal overflow; homepage refresh and logo return passed. JavaScript syntax and whitespace checks pass.
