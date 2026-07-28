# Clipio Demo — Visual Identity

## Style Prompt

An Apple-inspired macOS product film: calm, tactile, precise, and quietly delightful.
The Clipio shelf should feel like a real pane of Liquid Glass emerging from the menu bar,
with generous negative space, restrained highlights, and confident typography. The visual
language is native rather than futuristic: polished system materials, soft depth, and one
warm brand accent from the Clipio icon. Motion should feel responsive and physical, then
settle into stillness so the product remains the focus.

## Colors

- `#07111F` — deep navy canvas
- `#F4F8FF` — primary type and glass highlights
- `#AFC2D8` — secondary type and metadata
- `#8EDCFF` — selection, focus, and glass rim accent
- `#F4C84A` — Clipio brand accent and closing highlight

## Typography

- `Geist` — 800 for hero statements and 600 for product labels; its restrained,
  system-like proportions preserve the Apple-style register in deterministic renders
- `Geist Mono` — 600 for shortcuts and compact interaction labels

Use tight display tracking (`-0.035em`) and slightly open dark-canvas body leading.

## Motion

- Responsive entrances use `expo.out`, `power3.out`, and restrained `back.out(1.15)`.
- Product surfaces unfold or settle into place; scale overshoot must stay below `1.035`.
- Related scenes use smooth push transitions; chapter changes use a restrained blur crossfade.
- Ambient movement is limited to slow localized glows and subtle product parallax.
- Every scene builds quickly, breathes, then hands off while fully visible.

## Cover Direction

- Replace the generic glow field with a deliberate product-material macro: one oversized,
  softly lit Clipio glass shelf crops into the frame from the right.
- Build the canvas from the Clipio app icon: warm ivory, banana yellow, champagne gold,
  and a restrained chestnut reflection.
- Keep one cool spotlight behind the glass and one restrained warm reflection from the app icon.
- Anchor the icon and wordmark to the left with a smaller footprint and more breathing room.
- Remove the cyan underline. The glass rim itself is the highlight.
- The cover should read as an Apple product film still, not a generic technology wallpaper.

## Interaction Direction

- Cursor motion is calm and purposeful. A click uses one subtle compression and one soft ring.
- Keyboard actions are shown with restrained floating keycaps that are clearly editorial
  annotations, not part of Clipio's interface.
- Pinning must match the product: hover reveals the `pin + ⌥P` pill; the result is a permanent
  gold pin and a letter shortcut badge.
- The copy/paste story must remain literal: `⌘C` in the source app, Clipio captures after a
  short delay, `Return` chooses the item, and `⌘V` pastes in the destination app.

## What NOT to Do

- No cyberpunk neon, purple-blue gradient wash, or glowing particle field.
- No exaggerated glass glare, chromatic aberration, or fake 3D camera spins.
- No bouncy toy motion, aggressive glitch cuts, or constant ambient zoom.
- No dense explanatory copy; one clear product thought per scene.
- No visual claims that Clipio does not actually support.
- No fake “saved” toast presented as native Clipio UI.
- No implication that `Return` automatically pastes under the default settings.
