# Crystal Lens Liquid Glass — Design QA

Plan: `docs/superpowers/plans/2026-06-22-crystal-lens-liquid-glass.md`
Reference: `output/clipio-crystal-lens/option-1-reference.png`

## Machine-verified (assistant)

| Check | Result |
|---|---|
| `FloatingGlassStyleTests` (Crystal Lens tokens) | ✅ pass |
| Full `ClipioTests` suite (58 tests) | ✅ pass, 0 failures |
| Unsigned Debug build (`xcodebuild … build CODE_SIGNING_ALLOWED=NO`) | ✅ BUILD SUCCEEDED |

Code changes shipped:
- Crystal Lens tokens (lighter scrim/fill/tint, cyan + spectral-pink palette) in `FloatingGlassStyle`.
- Tray turned into a near-clear outer lens with a single 1-pt white/cyan/pink perimeter; header + cards grouped in one `GlassEffectContainer` on macOS 26.
- Cards made crystalline: lower fill/tint, 4-stop white→cyan→pink→white rim, neutral cool shadow, quieter footer.
- Search field tint reduced to the shared `cardTintOpacity` with a brighter white rim; header controls left neutral.

## Needs owner verification (live, macOS 26 + colorful wallpaper)

Capture the full 820×220 shelf with the first card selected, save as
`output/clipio-crystal-lens/implementation.png`, and place it beside
`option-1-reference.png` as `comparison.png`.

Acceptance criteria to confirm against the reference:
- [ ] Tray reads as clear glass; desktop colour travels through
- [ ] Cards separate cleanly from the tray and each other
- [ ] Spectral (cyan/pink) rim stays restrained, not neon
- [ ] Selected card is unambiguous
- [ ] Card text stays legible on bright and dark wallpapers
- [ ] Spacing and control order unchanged from before

Preserved interactions to exercise (record pass/fail here):
- [ ] Keyboard selection + auto-scroll
- [ ] Click-to-paste
- [ ] Hover preview popup
- [ ] Text drag-out
- [ ] Image drag-out *(note if the existing intermittent flakiness reproduces)*
- [ ] Pin-to-top / pin-to-bottom
- [ ] Clear / Shift-Clear All
- [ ] Settings
- [ ] Quit
