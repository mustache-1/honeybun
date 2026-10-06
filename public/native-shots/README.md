# Final Honeybun 1.0 native captures

The landing page currently displays vector reconstructions of the approved design concept, identified in image descriptions and the footer disclosure. They are visual review assets, not native app screenshots. Replace all six before production publishing.

Capture portrait iPhone 16 Pro at 1206 × 2622, current Phase 6/7 native build, populated fictional demo data, consistent appearance. Export clean full-screen images without a surrounding phone frame, keyboard, personal details, banners or added marketing text. Keep original aspect ratio. Optimize to WebP, 900–1206 px wide.

| Filename | Capture |
| --- | --- |
| home.webp | Home: current Safe to Spend, monthly context, upcoming bills and From Bun. No old Home streak. |
| insight.webp | From Bun: polished real spending observation and explanation. |
| plan.webp | Plan: populated monthly forecast, budgets and upcoming bills. |
| debt.webp | Debt Center+: current journey, estimated payoff, Snowball/Avalanche strategies. |
| goals.webp | Goals: populated active goals and recorded contribution progress. |
| together.webp | Together: shared household planning with actual shared/private boundaries. |

Set the corresponding six paths in `public/landing.js` to `/native-shots/<filename>`. Images load into individual reusable phone components; a failed image keeps the labeled concept preview. Captures need visual crop review because the reference intentionally shows partial phones. The verified App Store listing must also be configured in `public/app.js` before release; it is currently empty. No uploads or deployment are authorized in this website task.
