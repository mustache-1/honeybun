# Final Honeybun 1.0 native screenshot capture list

Internal audit status for all seven mappings: **PLACEHOLDER — RODRIGO MUST CAPTURE**. No current final native screenshots are displayed. Visitors see simple illustrated product panels without developer labels, capture instructions or invented app values. Older listing composites and reconstructed concept SVGs are not final Phase 7 screenshots and are not used by this page.

Use the final Phase 7 Honeybun native build on **iPhone 16 Pro simulator, portrait, 1206 × 2622**. Use consistent fictional demo data and the same current month and native dark theme throughout. Dismiss the keyboard, debug overlays, permission sheets and notification banners. Do not include personal account information.

Export the complete native screen including its native status bar. Do not add a phone frame, headline, gradient or marketing artwork. Do not stretch or crop individual UI elements. Suggested crop for every capture: **the full 1206 × 2622 screen, uncropped**. The website supplies a separate device frame. Keep originals; export optimized WebP at 900–1206 pixels wide, preserving the full aspect ratio.

| Slot / filename | Exact screen and desired state | What must be visible | Status |
| --- | --- | --- | --- |
| Home / `home.webp` | Home with populated current-month income, spending, carry-over and upcoming bills | Real Safe to Spend value, monthly context, upcoming bills and current From Bun entry. Do not put an old Home streak card back in the shot. | PLACEHOLDER — RODRIGO MUST CAPTURE |
| From Bun / `insight.webp` | Final Phase 7 From Bun with useful spending/budget observation and positive progress card | Friendly customer-facing explanation and “Why am I seeing this?” affordance, not internal priority, urgency, impact, timing or confidence labels. If the explanation cannot fit the initial viewport, capture a second optional detail image for later review. | PLACEHOLDER — RODRIGO MUST CAPTURE |
| Plan / `plan.webp` | This Month, populated budgets, bills and forecast | Current month selector, actual monthly forecast and category spending; upcoming bills where the native screen makes room. Capture the native viewport as-is rather than stitching separate parts together. | PLACEHOLDER — RODRIGO MUST CAPTURE |
| Debt Center+ / `debt.webp` | Populated debt journey with strategy comparison and supported estimated payoff results | Actual debt total, debt-free estimate, Snowball/Avalanche controls and interest/payoff comparison. Optional extra-payment exploration detail capture if it lives on another screen. | PLACEHOLDER — RODRIGO MUST CAPTURE |
| Goals / `goals.webp` | Active populated goals with recorded contributions | Real goal names, target amounts and progress. Include a supported projection only when the native UI actually provides one. | PLACEHOLDER — RODRIGO MUST CAPTURE |
| Together / `together.webp` | Populated shared household planning, using fictional shared entries | Actual shared planning summary and shared/private selection or boundary where visible. Do not expose private account data or imply bank-account sharing. | PLACEHOLDER — RODRIGO MUST CAPTURE |
| Bun Inbox / `inbox.webp` | Current native Inbox with representative notifications and current streak card location | Inbox title, readable real notification cards and streak card in its final Inbox location; no old debug UI. | PLACEHOLDER — RODRIGO MUST CAPTURE |

The simulator, orientation and full-screen crop instructions above apply to every row.

## Connecting the approved captures

Place each approved capture in this folder. Set each matching key in the `screenshots` map in `public/landing.js` to `/native-shots/<filename>`. Each component switches to its reviewed real native capture only after its configured image successfully loads. Missing/failed images retain the illustrated product panel. Capture status belongs in this internal guide, not public captions. From Bun and Inbox share a keyboard-accessible viewer; the other five appear separately in the product story. Review all frames at desktop and mobile sizes after replacement.

## App Store URL still required

`APPSTORE_URL` in `public/app.js` is empty. Supply the **verified public HTTPS App Store listing URL from App Store Connect** for Honeybun 1.0, of the form `https://apps.apple.com/<storefront>/app/<listing-slug>/id<actual-app-id>`. The actual numeric app ID/URL is not available here and must not be invented. All three marketing CTAs remain coming-soon controls until that URL exists.

This correction is for local visual approval only. Do not deploy, merge, upload TestFlight or begin submission work.
