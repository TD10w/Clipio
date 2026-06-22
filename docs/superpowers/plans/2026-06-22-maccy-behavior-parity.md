# Maccy Behavior Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Maccy's keyboard, pin-order, clear-history, and UI-automation behavior without replacing Clipio's card shelf.

**Architecture:** Keep behavior in the existing view and navigation types. Add small pure ordering/navigation seams for tests, render Clear through the existing footer actions, and expose each card through accessibility.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Xcode

---

### Task 1: Shelf ordering and navigation

**Files:**
- Modify: `MaccyTests/FloatingGlassStyleTests.swift`
- Modify: `Maccy/Views/HistoryListView.swift`
- Modify: `Maccy/Observables/NavigationManager.swift`
- Modify: `Maccy/Observables/AppState.swift`

- [ ] Add failing tests proving `.top` and `.bottom` shelf order and proving navigation does not enter a hidden footer.
- [ ] Run the focused tests and confirm the expected failures.
- [ ] Add a pure `HistoryListView.orderedItems` helper and a `footerNavigationEnabled` navigation boundary.
- [ ] Run the focused tests and confirm they pass.

### Task 2: Visible selection, scrolling, and accessibility

**Files:**
- Modify: `Maccy/Views/CardItemView.swift`
- Modify: `Maccy/Views/HistoryListView.swift`
- Modify: `MaccyUITests/MaccyUITests.swift`

- [ ] Update the UI-test contract to address horizontal cards and add a selected-card assertion.
- [ ] Confirm the UI test fails against the current shelf when the runner is available.
- [ ] Render selected-card styling, restore `copy-history-item` accessibility metadata, and scroll to `navigator.scrollTarget` with `ScrollViewReader`.
- [ ] Re-run the focused UI test.

### Task 3: Compact Clear control

**Files:**
- Modify: `Maccy/Views/HeaderView.swift`

- [ ] Add a header Clear control backed by the existing `FooterItem` actions and confirmation state.
- [ ] Make Shift choose Clear All while normal activation preserves pins.
- [ ] Verify existing keyboard Clear/Clear All commands open the same confirmation dialogs.

### Task 4: Full verification

**Files:**
- Verify only

- [ ] Run `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug -destination "platform=macOS" test CODE_SIGNING_ALLOWED=NO`.
- [ ] Run `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO` and require `BUILD SUCCEEDED`.
- [ ] Run `git diff --check`, inspect the final diff, and commit the verified implementation.
