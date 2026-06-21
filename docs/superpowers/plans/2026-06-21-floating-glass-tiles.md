# Floating Glass Tiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the selected Floating Glass Tiles concept in Clipio while preserving the current horizontal shelf and all clipboard interactions.

**Architecture:** Keep the existing AppKit floating panel and data flow intact. Centralize presentation metrics in a small Swift style namespace, use the panel glass as a light ambient tray, and render each card as its own elevated interactive glass surface with a macOS 26 native path and a material fallback.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, macOS 14 fallback, macOS 26 `glassEffect`/`NSGlassEffectView`.

**Visual source:** `output/clipio-ui-directions/02-floating-tiles.svg`

---

### Task 1: Lock the visual metrics with a failing test

**Files:**
- Create: `MaccyTests/FloatingGlassStyleTests.swift`
- Create: `Maccy/Views/FloatingGlassStyle.swift`
- Modify: `Clipio.xcodeproj/project.pbxproj`

- [ ] **Step 1: Register and write the failing test**

```swift
import XCTest
@testable import Clipio

final class FloatingGlassStyleTests: XCTestCase {
  func testSelectedDirectionUsesFloatingTileMetrics() {
    XCTAssertEqual(FloatingGlassStyle.cardWidth, 138)
    XCTAssertEqual(FloatingGlassStyle.cardHeight, 150)
    XCTAssertEqual(FloatingGlassStyle.cardRadius, 22)
    XCTAssertEqual(FloatingGlassStyle.cardSpacing, 12)
    XCTAssertEqual(FloatingGlassStyle.trayScrimOpacity, 0.06)
  }
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug test CODE_SIGNING_ALLOWED=NO -only-testing:ClipioTests/FloatingGlassStyleTests
```

Expected: compile failure because `FloatingGlassStyle` does not exist.

- [ ] **Step 3: Add the minimal style namespace**

```swift
import SwiftUI

enum FloatingGlassStyle {
  static let cardWidth: CGFloat = 138
  static let cardHeight: CGFloat = 150
  static let cardRadius: CGFloat = 22
  static let cardSpacing: CGFloat = 12
  static let trayScrimOpacity = 0.06
  static let cardTint = Color(red: 0.68, green: 0.88, blue: 1.0)
  static let rimTint = Color(red: 0.78, green: 0.97, blue: 1.0)
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: `FloatingGlassStyleTests` passes.

### Task 2: Make the panel a light ambient tray

**Files:**
- Modify: `Maccy/Views/ContentView.swift`
- Modify: `Maccy/Views/HeaderView.swift`
- Modify: `Maccy/Views/ListHeaderView.swift`
- Modify: `Maccy/Views/SearchFieldView.swift`
- Modify: `Maccy/Views/ToolbarView.swift`

- [ ] **Step 1: Replace the dark tray scrim**

Change the black `0.18` overlay in `ContentView` to a cool white/cyan `0.06` ambient wash using `FloatingGlassStyle.trayScrimOpacity`. Keep `GlassEffectView` and `VisualEffectView` as the system-rendered panel material.

- [ ] **Step 2: Increase header breathing room**

Use a 28-point title, a 34-point search field, and 28-point circular toolbar hit regions. Keep the existing search, settings, and quit actions.

- [ ] **Step 3: Add an interactive search surface**

On macOS 26, apply native interactive glass to the search field in a continuous rounded rectangle. On older systems, use `.ultraThinMaterial`, a faint cool fill, and a one-pixel white/cyan rim.

- [ ] **Step 4: Compile-check the tray and header**

Run the required build command and expect `BUILD SUCCEEDED`.

### Task 3: Rebuild cards as independent floating glass tiles

**Files:**
- Modify: `Maccy/Views/CardItemView.swift`
- Modify: `Maccy/Views/HistoryListView.swift`

- [ ] **Step 1: Apply the selected card metrics**

Replace the current 130×140 / 18-radius values with `FloatingGlassStyle` metrics. Use 12-point shelf spacing and slightly larger vertical/horizontal insets.

- [ ] **Step 2: Implement the native and fallback card surfaces**

On macOS 26, apply `.glassEffect(.regular.tint(FloatingGlassStyle.cardTint.opacity(...)).interactive(), in: .rect(cornerRadius: FloatingGlassStyle.cardRadius))` after layout. On older macOS, use `.regularMaterial`, a cool translucent tint, and the same continuous rounded shape.

- [ ] **Step 3: Add elevation and hover response**

Use a soft navy drop shadow at rest, a brighter cyan-white rim, and a two-point upward hover offset with a short ease-out animation. Preserve hover preview, shortcut selection, pin display, click-to-paste, and drag providers unchanged.

- [ ] **Step 4: Clarify card chrome**

Use a circular blue shortcut badge, a lighter translucent footer, readable semantic foreground colors, and content masking that follows the larger radius.

- [ ] **Step 5: Run focused and full verification**

Run `FloatingGlassStyleTests`, then the required build command. Expected: test pass and `BUILD SUCCEEDED`.

### Task 4: Capture and pass design QA

**Files:**
- Create: `design-qa.md`
- Create: `output/clipio-floating-glass/implementation.png`
- Create: `output/clipio-floating-glass/comparison.png`

- [ ] **Step 1: Launch the compiled Clipio app and open the shelf**

Use the existing app UI with realistic clipboard history. Capture the shelf at the same wide desktop scale as the selected concept.

- [ ] **Step 2: Compare source and implementation together**

Place `output/clipio-ui-directions/02-floating-tiles.svg` and the implementation capture into one comparison image. Review typography, spacing, color/material, imagery, icons, and content.

- [ ] **Step 3: Fix all P0/P1/P2 differences**

Repeat capture and comparison until only optional P3 polish remains.

- [ ] **Step 4: Write the blocking QA result**

Write `design-qa.md` with source path, implementation path, viewport/state, comparison evidence, findings, patches, and exactly `final result: passed`.

- [ ] **Step 5: Final verification and checkpoint commit**

Run:

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED`. Commit the verified UI checkpoint and report the short hash.
