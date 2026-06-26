# Pop-out "Unfold" Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shelf appear to unfold from a small glass chip at the top-center into the full card shelf (cards fading in once expanded), and collapse back quickly on close.

**Architecture:** The window opens instantly at its final size (correct hit-testing, no window motion). All motion happens inside SwiftUI: a `scaleEffect` (GPU transform, anchored top) on the whole `ContentView` unfolds the glass body from a thin chip to full size — the corner radius scales with it for free — while the header/cards fade in on a short delay. An `@Observable` flag on `AppState` is the AppKit→SwiftUI trigger: `FloatingPanel.open()` sets it true (unfold), `close()` sets it false (collapse).

**Tech Stack:** SwiftUI (`scaleEffect`, `.animation(value:)`, `.spring`), AppKit (`NSPanel`, `NSAnimationContext`), Observation (`@Observable`).

---

## Why this is lightweight (and bug-safe)

- `scaleEffect` is a GPU transform — **no per-frame relayout** of the card row.
- It returns to identity when expanded, so it **cannot** shift AppKit hit-testing the way the
  removed window-layer scale did (commit `3c6242e` mouse-offset bug). The `NSPanel` frame and
  layer are never touched.
- Only one observable Bool is added; no new timers, no polling.

## Testing approach

There is no automated harness for animation timing in this repo, and timing assertions are
brittle. Verification for every task is:

1. `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO` reports `BUILD SUCCEEDED`.
2. Final manual visual check by the owner on a **Release** build (Debug fakes extra lag).

Do not hand off until the build succeeds.

## File Structure

| File | Responsibility |
|---|---|
| `Maccy/Observables/AppState.swift` | Owns the `shelfExpanded` trigger flag |
| `Maccy/Views/FloatingGlassStyle.swift` | Owns the unfold tunable constants (seed scale, spring, fade) |
| `Maccy/Views/ContentView.swift` | Applies the unfold `scaleEffect` + delayed content fade, driven by the flag |
| `Maccy/FloatingPanel.swift` | Sets the flag on open/close; keeps the deferred-close pattern |

---

## Task 1: Add the trigger flag and tunable constants

**Files:**
- Modify: `Maccy/Observables/AppState.swift`
- Modify: `Maccy/Views/FloatingGlassStyle.swift`

- [ ] **Step 1: Add `shelfExpanded` to AppState**

In `Maccy/Observables/AppState.swift`, inside `class AppState`, add the property after the
existing stored vars (right after `var navigator: NavigationManager`):

```swift
  // Drives the pop-out "unfold" animation. FloatingPanel sets this true on open (the shelf
  // unfolds from a chip) and false on close (it collapses). ContentView animates off it.
  var shelfExpanded = false
```

- [ ] **Step 2: Add unfold tunables to FloatingGlassStyle**

In `Maccy/Views/FloatingGlassStyle.swift`, inside `enum FloatingGlassStyle`, add after the
existing constants (after `static let textCardTopPadding: CGFloat = 32`):

```swift
  // Pop-out "unfold" animation tunables — one-line changes to dial in the feel.
  // The shelf scales up from this seed (anchored top-center) into full size. Because the
  // whole view scales, the 30pt tray radius scales with it, giving the chip its pill shape.
  static let seedScaleX: CGFloat = 0.12   // chip width  ≈ 12% of full
  static let seedScaleY: CGFloat = 0.10   // chip height ≈ 10% of full (thin)
  static let unfoldResponse: Double = 0.34       // spring "duration" — deliberate end
  static let unfoldDamping: Double = 0.78        // <1 = small overshoot, not bouncy
  static let contentFadeDelay: Double = 0.16     // wait before cards fade in
  static let contentFadeDuration: Double = 0.16  // cards fade-in length
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Maccy/Observables/AppState.swift Maccy/Views/FloatingGlassStyle.swift
git commit -m "feat: add unfold trigger flag and animation tunables"
```

---

## Task 2: Apply the unfold animation in ContentView

**Files:**
- Modify: `Maccy/Views/ContentView.swift`

### Context

Current `body` is a `ZStack { trayGlass; KeyHandlingView { shelfContent } }` with an `.overlay`
rim stroke. We add:
- a delayed opacity fade on the `KeyHandlingView` (cards appear only after the unfold),
- a `scaleEffect` + spring on the whole composed view (the glass body unfolds),
both keyed on `appState.shelfExpanded`.

- [ ] **Step 1: Read the existing `body`**

Open `Maccy/Views/ContentView.swift` and locate `var body: some View`. Confirm it begins with
`ZStack {` containing `trayGlass` and the `KeyHandlingView`, followed by `.overlay(` and
`.animation(.easeInOut(duration: 0.2), value: appState.searchVisible)`.

- [ ] **Step 2: Add the delayed content fade to the KeyHandlingView**

Find this block:

```swift
      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        shelfContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
```

Replace it with:

```swift
      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        shelfContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      // Header + cards appear only once the glass has unfolded.
      .opacity(appState.shelfExpanded ? 1 : 0)
      .animation(
        .easeOut(duration: FloatingGlassStyle.contentFadeDuration)
          .delay(appState.shelfExpanded ? FloatingGlassStyle.contentFadeDelay : 0),
        value: appState.shelfExpanded
      )
```

- [ ] **Step 3: Add the unfold scaleEffect after the `.overlay`**

Find the line immediately after the closing `)` of the `.overlay(...)` modifier — it is:

```swift
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
```

Insert the following **directly above** that line (so it sits between `.overlay(...)` and the
search `.animation`):

```swift
    // The glass body unfolds from a small chip at the top-center into the full shelf.
    // scaleEffect is a GPU transform (no relayout) and settles to identity, so it can't
    // shift AppKit hit-testing the way the removed window-layer scale did.
    .scaleEffect(
      x: appState.shelfExpanded ? 1 : FloatingGlassStyle.seedScaleX,
      y: appState.shelfExpanded ? 1 : FloatingGlassStyle.seedScaleY,
      anchor: .top
    )
    .animation(
      .spring(
        response: FloatingGlassStyle.unfoldResponse,
        dampingFraction: FloatingGlassStyle.unfoldDamping
      ),
      value: appState.shelfExpanded
    )
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
Expected: `BUILD SUCCEEDED`

(At this point the flag is never set, so the shelf will render collapsed — that is fixed in
Task 3. Do not test the visual yet.)

- [ ] **Step 5: Commit**

```bash
git add Maccy/Views/ContentView.swift
git commit -m "feat: unfold scaleEffect and delayed content fade in ContentView"
```

---

## Task 3: Drive the flag from FloatingPanel open/close

**Files:**
- Modify: `Maccy/FloatingPanel.swift`

### Context

`open()` already shows the window at full size and runs a short alpha fade — we keep that and
add the SwiftUI unfold trigger. `close()` already defers `super.close()` via a completion
handler — we add the collapse trigger and lengthen the close slightly so the collapse reads.

- [ ] **Step 1: Lengthen the close duration**

In `Maccy/FloatingPanel.swift`, find:

```swift
private enum FloatingPanelAnim {
  static let openDuration: TimeInterval = 0.14
  static let closeDuration: TimeInterval = 0.10
}
```

Change `closeDuration` to:

```swift
  static let closeDuration: TimeInterval = 0.16
```

- [ ] **Step 2: Trigger the unfold in `open()`**

In `open(height:at:)`, find:

```swift
    orderFrontRegardless()
    makeKey()
    isPresented = true
```

Insert directly after `isPresented = true`:

```swift

    // Trigger the SwiftUI "unfold". Set on the next runloop so the collapsed seed state
    // renders for one frame first, giving the spring something to animate from.
    DispatchQueue.main.async {
      AppState.shared.shelfExpanded = true
    }
```

- [ ] **Step 3: Trigger the collapse in `close()`**

In `close()`, find:

```swift
    AppState.shared.appDelegate?.hidePreviewNow()
    isPresented = false
    statusBarButton?.isHighlighted = false
```

Insert directly after `statusBarButton?.isHighlighted = false`:

```swift
    // Collapse the shelf back toward the chip while the window fades out.
    AppState.shared.shelfExpanded = false
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Maccy/FloatingPanel.swift
git commit -m "feat: trigger shelf unfold/collapse from FloatingPanel open/close"
```

---

## Task 4: Manual verification and tuning handoff

**Files:** none (verification only)

- [ ] **Step 1: Final compile check**

Run: `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Owner visual check on a Release build**

Build/run the Release build and open the shelf with the shortcut several times. Confirm:
- The shelf unfolds from a small chip at the top-center (not a plain fade).
- Cards/header appear only after it has expanded — no jump or flicker.
- Closing collapses + fades quickly.
- Clicking a card immediately after open lands correctly (no mouse-offset).

- [ ] **Step 3: Tune the feel (if needed)**

All knobs are in `Maccy/Views/FloatingGlassStyle.swift`:
- Too slow/sluggish → lower `unfoldResponse` toward `0.20`.
- Too bouncy → raise `unfoldDamping` toward `0.9` (1.0 = no overshoot).
- Cards appear too early/late → adjust `contentFadeDelay`.
- Chip too big/small → lower `seedScaleX` / `seedScaleY`.
Close speed: `FloatingPanelAnim.closeDuration` in `Maccy/FloatingPanel.swift`.

Re-run the Step 1 build check after any change, then commit.

---

## Self-review notes

- **Spec coverage:** seed/unfold/fade tunables (Task 1) ✓; window fixed size + content-only
  motion (Task 2/3) ✓; cards fade in delayed (Task 2) ✓; AppKit↔SwiftUI flag coordination
  (Task 1/3) ✓; quick collapse on close (Task 3) ✓.
- **Deviation from spec:** the spec listed a separate `seedRadius` morph constant; we drop it
  because the corner radius scales automatically with the whole-view `scaleEffect`, so no
  explicit radius animation is needed. Lighter and visually equivalent.
- **Names are consistent across tasks:** `shelfExpanded`, `seedScaleX`, `seedScaleY`,
  `unfoldResponse`, `unfoldDamping`, `contentFadeDelay`, `contentFadeDuration`,
  `FloatingPanelAnim.closeDuration`.
