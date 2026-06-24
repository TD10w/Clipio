# Clipio — UI motion + file drag-out (design)

Date: 2026-06-24
Status: Approved for implementation (deferred to a future session)

## Context

Clipio is the horizontal card-shelf clipboard manager. Core principle: stay
lightweight, fast, responsive. This spec covers three small UI/UX additions agreed
during a brainstorming session. All three are intentionally cheap (opacity +
transform only) and must not regress the fast-open / smooth-scroll work already done.

Live files involved:
- `Maccy/FloatingPanel.swift` — the shelf window (`open()` / `close()`).
- `Maccy/Views/CardItemView.swift` — individual card (selection state, `dragProvider()`).
- `Maccy/Models/HistoryItem.swift` — `fileURLs: [URL]` (stored from `.fileURL` pasteboard data).

## Feature 1 — Open/close "pop" animation

**Goal:** when the shelf appears, it fades in while scaling up from ~96% → 100%
(a subtle pop); on close it reverses (scale down + fade out). Reinforces the
drop-down-shelf feel without feeling slow.

**Approach:**
- Animate the panel on `open()` and `close()` in `FloatingPanel`.
- Fade: animate `alphaValue` 0 → 1 (open) / 1 → 0 (close).
- Scale: apply a layer transform to `contentView` (anchor at center) from ~0.96 → 1.0.
  Alternative: drive a `scaleEffect` + `opacity` transition inside `ContentView`
  keyed on an "isShown" flag. Window-level alpha + contentView layer transform via
  `NSAnimationContext` is the most direct.
- Duration ~0.12–0.16s, ease-out. **Tunable** — the owner is unsure of the exact
  feel and wants to adjust speed/scale live in the app. Keep the magic numbers in
  one obvious place (e.g. named constants) so tuning is a one-line change.
- Close must let the animation finish before `orderOut`/`super.close()` — use the
  `NSAnimationContext` completion handler to defer the actual window teardown.
- Must not break: prewarm path (`prewarm()`/`finishPrewarming()`), `resignKey`
  auto-close, and the status-item / shortcut open paths. The animation should run
  on the user-facing open/close, not during prewarm.

**Risk:** medium-low. Touches the window lifecycle; verify open, click-outside
close, ⌘⇧C toggle close, and prewarm all still behave.

## Feature 2 — Card selection "scale pop"

**Goal:** when a card becomes selected (click or arrow-key), it briefly bumps to
~106% and springs back, alongside the existing accent ring.

**Approach:**
- In `CardItemView`, drive a short spring `scaleEffect` keyed on `item.isSelected`
  (and/or a one-shot trigger when selection changes), using `.animation`/`.spring`.
- Keep the existing accent-ring overlay. Ensure the scale uses a center anchor and
  does not shift the hit area or clip against neighbors (cards sit in a `LazyHStack`
  with `cardSpacing`; a 6% bump should fit within spacing — verify no clipping).
- Lightweight: pure transform, no shadows added.

**Risk:** low. Pure SwiftUI view effect.

## Feature 3 — Drag files OUT

**Goal:** dragging a file-type card out of Clipio drops the real file into Finder /
other apps, mirroring the existing image/text drag.

**Approach:**
- In `CardItemView.dragProvider()`, add a branch before/after the image branch:
  if `item.item.fileURLs` is non-empty, register the file URL(s) on the
  `NSItemProvider` so the OS treats the drag as a file (e.g. `NSItemProvider(contentsOf:)`
  per URL, or register a file representation / the `public.file-url` type). Prefer
  the API that yields a real file drop in Finder.
- Keep `panel.isDragging = true` (already set) so the panel stays open mid-drag.
- Drag preview: show the file name (and/or icon) instead of the text/image preview.

**Caveat (document in UI/help, not a bug):** the drag uses the file's stored URL
(a reference). If the original file was moved/deleted, the drag won't produce it —
consistent with macOS file-clipboard behavior.

**Risk:** low. Only runs during a drag; no at-rest cost; additive branch.

## Out of scope (future, separate spec)

- **Dropping files INTO the shelf** to add them to history. Needs a drop target +
  a decision on storing file references vs. copying contents + dedupe with the
  existing `History.add()` pipeline. Revisit once drag-out is proven.

## Verification (per feature, in the installed Release build)

- Open/close: shelf pops in/out smoothly; toggling ⌘⇧C and click-outside close both
  animate; open still feels fast; prewarm unaffected.
- Card select: clicking and arrowing to a card both produce the pop; no clipping.
- File drag: drag a file card into a Finder window → the real file lands there.

## Notes for next session

- Build/test via the installed Release app (`Install Clipio.command` or the
  build+copy-to-`/Applications` flow). Do NOT judge performance from Xcode `Cmd+R`
  (Debug) — Debug SwiftUI is far laggier and misled us repeatedly this session.
- Implement incrementally, one feature per commit, compile-check before handoff.
