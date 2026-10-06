# Concept-derived illustration assets

Built-in imagegen edited Rodrigo's supplied approved concept PNG; these are separately reconstructed artwork assets, not a flattened website. PNG source outputs are retained in the imagegen output directory. Only optimized WebP files are served.

Hero prompt:

Use case: precise-object-edit. Edit target: supplied approved Honeybun landing page concept. Create a landscape hero illustration asset ONLY, corresponding exactly to the top illustrated band of this image. Preserve the approved character design, pose and composition: white pink-cheeked witch Bun in purple hat hugging glowing honey jar seated on rocky foreground, sleeping small companion to its left, lantern to right, orange-lit lakeside village beyond, crescent moon, purple mountains, pine forest, autumn foliage framing edges. Preserve this artwork faithfully rather than inventing another mascot. Remove ALL website typography, logos, buttons, navigation, phone screens, product sections and UI. Remove lettering from the wooden sign, leaving the wooden sign blank. Make the left 38% dark uncluttered space for real HTML headline. Witch Bun central at 54% width; village and moon on right; blank wooden sign near right edge. Wide 2.4:1 composition. Premium illustrated nighttime dark plum/purple and warm orange lighting, exactly matching reference. Bottom edge gently fades into deep plum #170b22 for continuation into HTML product sections. Output just this standalone hero environment illustration, no website mockup.

Forest prompt:

Use case: precise-object-edit. Input is approved Honeybun landing-page concept. Extract/reconstruct ONLY the illustrated environment behind the lower product sections into a standalone portrait background asset. Remove ALL typography, phone devices, buttons, UI, feature cards, icons, and ALL bunny characters. Preserve the actual visual language: dark purple layered mountain silhouettes and pine forest, deep plum night sky, very subtle stars/embers, rich autumn orange/plum foliage around left/right edges, tiny lanterns and pumpkins low along the edges, a warm low glow near bottom. Center 75% stays predominantly dark calm plum negative space for real HTML content, not busy. Top edge fades to #170b22. This is an atmospheric scenery asset, NOT a website mockup. No text, no cards, no phones. Portrait 2:3 proportions. Match the approved reference precisely.


## Current reference implementation

`reference/` supersedes the earlier reconstructed art. The hero characters, sign, peeking Buns, couple, phone concept previews, icons and orange App Store buttons were cropped from the user's approved 1024 × 1536 PNG and supplied detail crops. No replacement characters were generated. Phone previews are labeled as concept imagery, pending final native captures.

`reference/scene.webp` contains scenery only. Imagegen removed text, UI, phones, cards and characters from the reference; unaffected scenery was restored from the original using an alpha mask, and cleaned scenery fills the covered areas. The HTML is not a flattened concept image: headings, paragraphs, navigation, cards, responsive arrangement and phone slots are independent elements. Cleared scenery under covered content cannot be pixel-identical to the original; visible character artwork comes from the exact supplied reference.

Animation consists of a soft honey glow, one drifting ember, subtle hover movement and short scroll reveals, all disabled with reduced motion.


## Higher-quality assets

`crisp/` is the current implementation. Phone/device/feature/trust artwork and button lettering are scalable SVG/HTML. Phone layouts are explicit design-concept reconstructions; final native imagery remains pending. The hero was repaired through imagegen from the reference into one continuous 2048 × 768 scene, filling the former staircase-shaped cutout and restoring detail. A second edit restored the three small character illustrations with transparent alpha and warm glow. The atmosphere, characters, sign, section arrangement and copy retain the approved direction. Old assets remain in the repository for comparison.


Follow-up: scene-clean.webp uses the fully cleaned scenic output without any original crop overlays, eliminating faint baked-in phone/crop borders. The Goals peeking illustration is removed from the page. The header mascot is restored from the exact original tiny reference as a high-resolution transparent illustration. Small fireflies are distributed over the entire landing page.


scene-single-lantern.webp is the current scenic background. A precise image edit removed only the lower-right background lantern to prevent duplication beside the couple sprite. The hero illustration is unchanged. The eyebrow heart uses a small SVG, and From Bun's transparent sprite is tucked further behind its device edge.


## Responsive correction (local approval build)

The environment now spans the viewport; independently bounded HTML grids contain copy and individual device frames. There is no page-wide canvas scaling. `crisp/hero-scene.webp` (2048 × 768) and `crisp/scene-single-lantern.webp` (1024 × 1536) remain the approved continuous artwork. Transparent insight/couple artwork remains separate; the unwanted Goals peek stays removed.

`responsive/hero-mobile.webp` (1280 × 480, approximately 103 KB) and `responsive/world-mobile.webp` (640 × 960, approximately 80 KB) are proportionally resized WebP derivatives of those same assets. They introduce no new artwork or product claims. The hero uses a responsive picture source; the mobile scenic background selects its smaller asset in CSS. Below-the-fold character illustrations load lazily.

Concept phone SVG reconstructions are retired from the landing markup. All seven product slots are explicitly labeled placeholders for final real native captures; see `../native-shots/README.md`. Fireflies and a few drifting leaves use CSS-only motion, with reduced-motion suppression. Existing files remain for provenance but are not loaded by the landing page unless referenced.
