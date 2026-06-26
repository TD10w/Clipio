# Pop-out "Unfold" Animation — Design

**Date:** 2026-06-26
**Status:** Approved for planning (pending owner spec review)

## Goal

Replace the shelf's current plain alpha-fade open with a **"liquid glass unfold"** — the
shelf appears to grow from a small chip at the top-center of the screen into the full
card shelf, with the cards fading in only once it has expanded. Inspired by the Goldfish
app's orange-panel morph (Dynamic-Island / Spotlight style), but tuned to feel smooth
and deliberate rather than gimmicky.

Close reverses the motion quickly.

## What "the effect" is (confirmed against reference)

1. Panel starts as a **small rounded chip** at the top-center (where the shelf already drops from).
2. The **glass body grows outward + downward** into the full shelf size, with a soft spring and a corner-radius morph.
3. The **header + cards fade in only at the end**, once the body is mostly expanded — they do not animate during the morph.
4. **Close** collapses/fades back quickly toward the compact shape.

## Constraints / non-negotiables

- **Lightweight.** No per-frame relayout of the card row. The clipboard manager is summoned
  constantly; the animation must stay cheap and never make the app feel heavy.
- **No mouse-offset regression.** Commit `3c6242e` removed a CA-layer scale animation because
  scaling the window's layer shifted the click coordinate space mid-animation. The new design
  must not move or scale the **window** — only content *inside* a fixed-size window.
- **Tunable feel.** Durations / spring / seed size live in named constants so the owner can dial
  the feel on a Release build (Debug fakes extra lag — always judge on Release).

## Chosen approach — "B: Faithful unfold, lightweight"

(Approaches A "cheap scale+fade" and C "true window resize" were considered and rejected:
A doesn't capture the unfold; C animates the real `NSPanel` frame → per-frame relayout +
window motion = the heavy/risky path.)

**Principle:** the window opens *instantly at its final size* (correct hit-testing always), and
all motion happens in SwiftUI *inside* that fixed window.

### Window layer — `Maccy/FloatingPanel.swift`

- `open()` shows the window at full size immediately. Keep a very short window-alpha fade
  (or snap to 1) — the perceived animation is now driven by SwiftUI, not window alpha.
- The panel never changes its frame or layer scale during the animation. The mouse-offset
  bug is structurally impossible.
- A shared flag drives the SwiftUI animation (see coordination below).
- `close()` keeps the existing deferred-`super.close()` pattern: set the flag to "collapsed",
  then commit the close after the close duration via the existing completion handler.

### SwiftUI layer — `Maccy/Views/ContentView.swift`

The existing `ZStack { trayGlass; KeyHandlingView { shelfContent } }` is the seam:

- **`trayGlass`** (the single glass lozenge) is the body that **unfolds**: animate its
  rendered size from a small chip (≈ `seedWidth` × `seedHeight`, anchored top-center) to full,
  with a soft spring and a `cornerRadius` morph (`seedRadius` → `trayRadius`).
- **`shelfContent`** (header + cards) stays laid out at full size the whole time — only its
  **opacity** (and a tiny scale, optional) animates from 0 → 1 with a short delay, so it
  appears only after the body has expanded. Because layout is computed once and only opacity
  animates, there is **no card relayout churn** — this is what keeps it light.
- The expanding body is a single rounded rect; that is the only thing whose geometry animates.

### Coordination AppKit ↔ SwiftUI

The window is reused (prewarm), so `onAppear` is unreliable per-open. Use an explicit trigger
on `AppState` (mirroring the existing Int-epoch selection-pop pattern):

- An observable flag/epoch, e.g. `AppState.shared.shelfExpanded: Bool` (or an `openEpoch: Int`).
- `FloatingPanel.open()` sets it to expanded **after** ordering the window front.
- `FloatingPanel.close()` sets it to collapsed, then commits `super.close()` after the close
  duration (reuse the existing `NSAnimationContext` completion handler / timer).
- `ContentView` reads the flag and animates the tray size + content opacity accordingly.

## Tunables (named constants)

Recommended starting values (owner dials on Release build):

| Constant | Start value | Meaning |
|---|---|---|
| `seedWidth` | ~64 pt | chip width before unfold |
| `seedHeight` | ~18 pt | chip height before unfold |
| `seedRadius` | ~9 pt | chip corner radius (morphs to `trayRadius` = 30) |
| `openExpandDuration` | ~0.30 s | body unfold (soft spring) |
| `contentFadeDelay` | ~0.16 s | wait before cards fade in |
| `contentFadeDuration` | ~0.16 s | cards fade-in |
| `closeDuration` | ~0.16 s | collapse + fade on close |

Spring: a soft spring with a *small* overshoot (not bouncy). Owner wanted it deliberate
(≈ the "3× slow-motion" preview feel); ~0.30 s is the deliberate end — if it feels sluggish
in daily use, drop `openExpandDuration` toward ~0.20 s. One-line change.

## Files touched

| File | Change |
|---|---|
| `Maccy/Views/ContentView.swift` | Animate `trayGlass` size + radius from seed→full; fade `shelfContent` in delayed; read the expand flag |
| `Maccy/FloatingPanel.swift` | Open instantly at full size; set/clear the expand flag in `open()`/`close()`; keep deferred close |
| `Maccy/Observables/AppState.swift` (or similar) | Add the `shelfExpanded` flag / `openEpoch` trigger |
| `Maccy/Views/FloatingGlassStyle.swift` | Add the seed/duration tunable constants |

## Out of scope

- No new glass rendering / no GlassEffectContainer changes — reuse the existing tray glass.
- No change to card content, search, or drag behavior.
- Per-card selection-pop animation already exists and is untouched.

## Risks

- **Spring overshoot reintroducing visual jump:** keep overshoot small; the body scales,
  the window does not — so even an overshoot can't shift hit-testing.
- **Glass `glassEffect` resizing cost:** the tray uses native `glassEffect` on macOS 26.
  If animating its frame proves expensive, fall back to animating a `scaleEffect` (GPU
  transform, anchored top) on the tray instead of its frame — visually near-identical for a
  small size delta, zero relayout. Decide during implementation if needed.
