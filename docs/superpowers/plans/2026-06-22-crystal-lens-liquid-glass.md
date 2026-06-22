# Crystal Lens Liquid Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Option 1 Crystal Lens material system without changing Clipio's layout or clipboard interactions.

**Architecture:** Keep the AppKit floating panel, SwiftUI view hierarchy, and behavior unchanged. Centralize the revised visual tokens in `FloatingGlassStyle`, reduce the tray's custom wash so native glass can sample the desktop, and tune existing search/card/rim modifiers rather than adding a second styling system. Use macOS 26 native glass as the primary path and preserve a lightweight system-material fallback.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, macOS 26 `NSGlassEffectView`/`glassEffect`, macOS 14+ material fallback.

**Design spec:** `docs/superpowers/specs/2026-06-22-crystal-lens-liquid-glass-design.md`

**Visual source:** `output/clipio-crystal-lens/option-1-reference.png`

---

### Task 1: Lock the Crystal Lens tokens

**Files:**
- Modify: `MaccyTests/FloatingGlassStyleTests.swift`
- Modify: `Maccy/Views/FloatingGlassStyle.swift`

- [ ] **Step 1: Change the token test first**

Update `testSelectedDirectionUsesFloatingTileMetrics` so it preserves all geometry and expects the lighter material values:

```swift
func testSelectedDirectionUsesCrystalLensMetrics() {
  XCTAssertEqual(FloatingGlassStyle.cardWidth, 138)
  XCTAssertEqual(FloatingGlassStyle.cardHeight, 150)
  XCTAssertEqual(FloatingGlassStyle.cardRadius, 22)
  XCTAssertEqual(FloatingGlassStyle.cardSpacing, 12)
  XCTAssertEqual(FloatingGlassStyle.trayScrimOpacity, 0.06)
  XCTAssertEqual(FloatingGlassStyle.cardFillOpacity, 0.055)
  XCTAssertEqual(FloatingGlassStyle.cardTintOpacity, 0.10)
  XCTAssertEqual(FloatingGlassStyle.trayRadius, 28)
  XCTAssertEqual(FloatingGlassStyle.searchHeight, 32)
  XCTAssertEqual(FloatingGlassStyle.toolbarControlSize, 28)
  XCTAssertEqual(FloatingGlassStyle.textCardTopPadding, 32)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug test CODE_SIGNING_ALLOWED=NO -only-testing:ClipioTests/FloatingGlassStyleTests
```

Expected: failure because the old scrim is `0.18` and the new opacity tokens do not exist.

- [ ] **Step 3: Implement the token set**

Keep all geometry and replace/add these material values in `FloatingGlassStyle`:

```swift
static let trayScrimOpacity = 0.06
static let cardFillOpacity = 0.055
static let cardTintOpacity = 0.10
static let cardTint = Color(red: 0.82, green: 0.94, blue: 1.0)
static let rimTint = Color(red: 0.72, green: 0.95, blue: 1.0)
static let spectralTint = Color(red: 1.0, green: 0.72, blue: 0.92)
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: `FloatingGlassStyleTests` passes.

- [ ] **Step 5: Commit the token checkpoint**

```bash
git add MaccyTests/FloatingGlassStyleTests.swift Maccy/Views/FloatingGlassStyle.swift
git commit -m "Define Crystal Lens glass tokens"
```

### Task 2: Turn the panel into a clear outer lens

**Files:**
- Modify: `Maccy/Views/ContentView.swift`
- Modify: `Maccy/FloatingPanel.swift`

- [ ] **Step 1: Replace the strong ambient wash**

Keep `GlassEffectView`/`VisualEffectView`, but replace the current gradient with:

```swift
LinearGradient(
  colors: [
    Color.white.opacity(FloatingGlassStyle.trayScrimOpacity + 0.02),
    FloatingGlassStyle.cardTint.opacity(FloatingGlassStyle.trayScrimOpacity),
    FloatingGlassStyle.spectralTint.opacity(0.018)
  ],
  startPoint: .topLeading,
  endPoint: .bottomTrailing
)
.allowsHitTesting(false)
```

- [ ] **Step 2: Add a restrained tray perimeter**

Overlay the root content with a 28-point continuous rounded rectangle using a one-point white/cyan/pink gradient. Keep the existing clear `NSPanel` background and corner radius; do not add an opaque panel fill.

- [ ] **Step 3: Group the nearby custom glass surfaces**

Extract the existing header/list stack into a `shelfContent` view builder. On macOS 26, place that content in one `GlassEffectContainer(spacing: FloatingGlassStyle.cardSpacing)` so search, controls, and cards sample a coherent glass field. Render the same `shelfContent` directly on older macOS.

- [ ] **Step 4: Compile-check the outer lens**

Run the required unsigned Debug build. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit the tray checkpoint**

```bash
git add Maccy/Views/ContentView.swift Maccy/FloatingPanel.swift
git commit -m "Refine shelf as clear glass lens"
```

### Task 3: Make cards crystalline instead of acrylic

**Files:**
- Modify: `Maccy/Views/CardItemView.swift`

- [ ] **Step 1: Tune the macOS 26 card modifier**

In `FloatingGlassCardBackground`, preserve `.interactive()` and the 22-point shape, but use the centralized lower opacities:

```swift
content
  .background(
    Color.white.opacity(isHovered ? 0.09 : FloatingGlassStyle.cardFillOpacity),
    in: shape
  )
  .glassEffect(
    .regular
      .tint(FloatingGlassStyle.cardTint.opacity(
        isHovered ? 0.16 : FloatingGlassStyle.cardTintOpacity
      ))
      .interactive(),
    in: .rect(cornerRadius: CardItemView.cardRadius)
  )
  .modifier(FloatingGlassRim(isHovered: isHovered))
```

- [ ] **Step 2: Tune the older macOS fallback**

Keep `.regularMaterial`, but reduce the cool overlay to `0.12` at rest and `0.17` on hover. Use the same rim and geometry as macOS 26.

- [ ] **Step 3: Refine rim and shadow**

Use white → cyan → faint pink → low white in the rim gradient. Keep one point at rest and 1.5 points on hover. Change the shadow to a neutral cool black around `0.18` opacity at rest and `0.26` on hover; preserve the current radii and two-point lift.

- [ ] **Step 4: Quiet the footer**

Change the footer fill from `Color.white.opacity(0.08)` to approximately `0.045`, retain the half-point top separator, and verify source icons/times remain legible.

- [ ] **Step 5: Run focused tests and compile-check**

Run `FloatingGlassStyleTests`, then the required unsigned Debug build. Expected: tests pass and `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit the card checkpoint**

```bash
git add Maccy/Views/CardItemView.swift
git commit -m "Make clipboard cards crystalline"
```

### Task 4: Harmonize search and header controls

**Files:**
- Modify: `Maccy/Views/SearchFieldView.swift`
- Modify: `Maccy/Views/HeaderView.swift`

- [ ] **Step 1: Reduce search tint**

Keep the 32-point size and existing search behavior. On macOS 26, use the same low `cardTintOpacity` and a white rim near `0.32`; on fallback, use `.ultraThinMaterial` with no more than `0.12` cool fill.

- [ ] **Step 2: Keep action controls neutral**

Retain the native interactive circular glass controls and 28-point size. Keep trash, gear, and power monochrome. Do not add colored backgrounds.

- [ ] **Step 3: Compile-check and commit**

Run the required build. Expected: `BUILD SUCCEEDED`.

```bash
git add Maccy/Views/SearchFieldView.swift Maccy/Views/HeaderView.swift
git commit -m "Harmonize Crystal Lens header controls"
```

### Task 5: Verify behavior and visual fidelity

**Files:**
- Create: `output/clipio-crystal-lens/implementation.png`
- Create: `output/clipio-crystal-lens/comparison.png`
- Create: `output/clipio-crystal-lens/design-qa.md`

- [ ] **Step 1: Run the full unit suite**

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug test CODE_SIGNING_ALLOWED=NO -only-testing:ClipioTests
```

Expected: all Clipio unit tests pass.

- [ ] **Step 2: Run the required compile-check**

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Capture a realistic shelf**

Open Clipio on macOS 26 with five mixed clipboard entries and a colorful wallpaper. Capture the full 820×220 shelf with the first card selected.

- [ ] **Step 4: Compare with the approved reference**

Place `option-1-reference.png` and `implementation.png` side-by-side in `comparison.png`. Check tray transparency, card separation, spectral rim restraint, selection clarity, text contrast, spacing, and unchanged control order.

- [ ] **Step 5: Exercise the preserved interactions**

Verify keyboard selection and auto-scroll, click-to-paste, hover preview, text drag, image drag, pin-top/pin-bottom, Clear, Shift-Clear All, Settings, and Quit. Record pass/fail evidence in `design-qa.md`; note image drag separately if its existing intermittent behavior reproduces.

- [ ] **Step 6: Fix all blocking visual or behavior regressions**

Repeat build and capture until the design spec's six acceptance criteria pass.

- [ ] **Step 7: Commit the verified UI checkpoint**

```bash
git add Maccy MaccyTests output/clipio-crystal-lens
git commit -m "Adopt Crystal Lens Liquid Glass"
```

Report the final short hash and do not include unrelated `project.pbxproj` normalization in the commit.
