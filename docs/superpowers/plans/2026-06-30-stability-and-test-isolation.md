# Clipio Stability and Test Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix pinning and rapid reopen regressions, isolate automated tests from the owner's live Clipio and system clipboard, restore disabled history tests, and remove the known Swift 6 warning.

**Architecture:** Add one shared runtime-environment check used by storage and app startup. Keep normal production behavior unchanged while test runs skip global side effects and inject a private pasteboard. Model close-animation validity with a small testable state value, and route card pin actions through the existing history owner.

**Tech Stack:** Swift, SwiftUI, AppKit, SwiftData, XCTest, Xcode test plans

---

## File map

- Create `Maccy/RuntimeEnvironment.swift`: shared test-mode detection only.
- Modify `Clipio.xcodeproj/project.pbxproj`: register the new Swift file in the Clipio target.
- Modify `Maccy/Storage.swift`: use the shared test-mode check for in-memory storage.
- Modify `Maccy/AppDelegate.swift`: skip single-instance termination and runtime clipboard startup in tests.
- Modify `Maccy/Observables/Popup.swift`: skip global shortcut/event registration in tests.
- Modify `Maccy/Clipboard.swift`: accept an injected pasteboard while defaulting to the real system pasteboard.
- Modify `MaccyTests/ClipboardTests.swift`: use a private named pasteboard.
- Modify `Maccy/Views/CardItemView.swift`: route both pin controls through the history owner.
- Modify `Maccy/FloatingPanel.swift`: reject stale close-animation completions.
- Modify `Maccy/Observables/AppState.swift`: remove unnecessary `Sendable` conformance.
- Modify `MaccyTests/FloatingGlassStyleTests.swift`: add focused runtime, pin, and animation-state regression tests.
- Modify `Maccy.xctestplan`: restore `HistoryTests`.

### Task 1: Shared test-mode contract

**Files:**
- Create: `Maccy/RuntimeEnvironment.swift`
- Modify: `Clipio.xcodeproj/project.pbxproj`
- Modify: `Maccy/Storage.swift:20-27`
- Test: `MaccyTests/FloatingGlassStyleTests.swift`

- [ ] **Step 1: Write the failing runtime-environment test**

Add to `FloatingGlassStyleTests`:

```swift
func testTestRunUsesIsolatedRuntimeEnvironment() {
  XCTAssertTrue(RuntimeEnvironment.isTesting)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/ClipioStabilityDerivedData test \
  -only-testing:ClipioTests/FloatingGlassStyleTests/testTestRunUsesIsolatedRuntimeEnvironment \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because `RuntimeEnvironment` does not exist.

- [ ] **Step 3: Add the minimal shared helper**

Create `Maccy/RuntimeEnvironment.swift`:

```swift
import Foundation

enum RuntimeEnvironment {
  static var isTesting: Bool {
    CommandLine.arguments.contains("enable-testing")
  }
}
```

Register the file in the main Clipio group and Clipio Sources build phase in `project.pbxproj`. Replace the conditional in `Storage.init()` with:

```swift
#if DEBUG
if RuntimeEnvironment.isTesting {
  config = ModelConfiguration(isStoredInMemoryOnly: true)
}
#endif
```

- [ ] **Step 4: Re-run the focused test and verify GREEN**

Expected: the focused test passes.

### Task 2: Isolate the test host and clipboard

**Files:**
- Modify: `Maccy/AppDelegate.swift:61-95`
- Modify: `Maccy/Observables/Popup.swift:50-57`
- Modify: `Maccy/Clipboard.swift:5-33`
- Modify: `MaccyTests/ClipboardTests.swift:6-44`

- [ ] **Step 1: Write the failing private-pasteboard test**

Change the test fixture to request a private pasteboard and add:

```swift
let pasteboard = NSPasteboard(name: .init("com.clipio.tests.\(UUID().uuidString)"))
lazy var clipboard = Clipboard(pasteboard: pasteboard)

func testUsesInjectedPasteboardWithoutChangingSystemPasteboard() {
  let systemChangeCount = NSPasteboard.general.changeCount

  clipboard.copy("isolated")

  XCTAssertEqual(pasteboard.string(forType: .string), "isolated")
  XCTAssertEqual(NSPasteboard.general.changeCount, systemChangeCount)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Expected: compile failure because `Clipboard` has no `pasteboard` initializer.

- [ ] **Step 3: Add pasteboard injection**

Change `Clipboard` to:

```swift
private let pasteboard: NSPasteboard

init(pasteboard: NSPasteboard = .general) {
  self.pasteboard = pasteboard
  changeCount = pasteboard.changeCount
}
```

Update all `ClipboardTests` cases to use the private fixture pasteboard rather than `NSPasteboard.general`.

- [ ] **Step 4: Suppress global app side effects in test mode**

In `AppDelegate.applicationWillFinishLaunching`, do not terminate another Clipio when `RuntimeEnvironment.isTesting`. After assigning the app delegate bridge, return before installing clipboard hooks, starting the timer, or registering runtime observers:

```swift
if !RuntimeEnvironment.isTesting {
  terminateOtherRunningCopies()
}

AppState.shared.appDelegate = self
guard !RuntimeEnvironment.isTesting else { return }
```

Extract the existing same-bundle termination loop into `terminateOtherRunningCopies()` without changing normal behavior.

In `Popup.init()`:

```swift
guard !RuntimeEnvironment.isTesting else { return }
KeyboardShortcuts.onKeyDown(for: .popup, action: handleFirstKeyDown)
initEventsMonitor()
```

- [ ] **Step 5: Run all ClipboardTests and verify GREEN**

Expected: every Clipboard test passes and the injected-pasteboard assertion confirms the general pasteboard was not changed.

### Task 3: Route card pinning through History

**Files:**
- Modify: `Maccy/Views/CardItemView.swift:105-143`
- Test: `MaccyTests/FloatingGlassStyleTests.swift`

- [ ] **Step 1: Write the failing card-pin action test**

Add:

```swift
@MainActor
func testCardPinActionUsesHistoryOwner() {
  final class RecordingHistory: History {
    var toggledItem: HistoryItemDecorator?

    override func togglePin(_ item: HistoryItemDecorator?) {
      toggledItem = item
    }
  }

  let history = RecordingHistory()
  let item = HistoryItemDecorator(HistoryItem())

  CardItemView.togglePin(item, in: history)

  XCTAssertIdentical(history.toggledItem, item)
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Expected: compile failure because the card action entry point does not exist.

- [ ] **Step 3: Add the minimal action entry point and use it from both buttons**

Add an internal helper on `CardItemView`:

```swift
@MainActor
static func togglePin(_ item: HistoryItemDecorator, in history: History) {
  history.togglePin(item)
}
```

Both pin buttons call:

```swift
Task { @MainActor in
  Self.togglePin(item, in: AppState.shared.history)
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: the new card-pin action test passes.

### Task 4: Prevent stale close animations

**Files:**
- Modify: `Maccy/FloatingPanel.swift:4-228`
- Test: `MaccyTests/FloatingGlassStyleTests.swift`

- [ ] **Step 1: Write the failing animation-state test**

Add:

```swift
func testReopenInvalidatesPendingCloseCompletion() {
  var state = FloatingPanelAnimationState()
  let closeToken = state.beginClose()

  state.didOpen()

  XCTAssertFalse(state.canFinishClose(closeToken))
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Expected: compile failure because `FloatingPanelAnimationState` does not exist.

- [ ] **Step 3: Add minimal token state and wire it to the panel**

Add near the animation tunables:

```swift
struct FloatingPanelAnimationState {
  private var generation = 0

  mutating func didOpen() {
    generation += 1
  }

  mutating func beginClose() -> Int {
    generation += 1
    return generation
  }

  func canFinishClose(_ token: Int) -> Bool {
    token == generation
  }
}
```

Store one state value on `FloatingPanel`. Call `didOpen()` at the beginning of `open`. Capture `beginClose()` in `close`, then guard the completion before `commitClose()`:

```swift
guard self.animationState.canFinishClose(closeToken), !self.isPresented else { return }
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: the reopen regression test passes.

### Task 5: Remove the Swift 6 warning

**Files:**
- Modify: `Maccy/Observables/AppState.swift:7-8`

- [ ] **Step 1: Capture the existing compiler warning as RED evidence**

Run a clean Debug build and confirm it reports that mutable `AppState` cannot safely conform to `Sendable` in Swift 6 mode.

- [ ] **Step 2: Remove only the unnecessary conformance**

Change:

```swift
class AppState: Sendable {
```

to:

```swift
final class AppState {
```

- [ ] **Step 3: Rebuild and verify GREEN**

Expected: build succeeds and the `AppState` Sendable warnings are absent.

### Task 6: Restore HistoryTests and prove data safety

**Files:**
- Modify: `Maccy.xctestplan:24-47`

- [ ] **Step 1: Remove the `skippedTests` block for HistoryTests**

Keep the `ClipioTests` target entry, but delete the suite and method skip list so all 13 existing history tests run.

- [ ] **Step 2: Capture production safety baselines without reading contents**

Record the production `ZHISTORYITEM` and `ZHISTORYITEMCONTENT` counts, database/WAL modification timestamps, and `NSPasteboard.general.changeCount`.

- [ ] **Step 3: Run the complete ClipioTests target**

Run:

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/ClipioStabilityDerivedData test \
  -only-testing:ClipioTests CODE_SIGNING_ALLOWED=NO
```

Expected: 75 tests pass with zero failures: the current 58, the restored 13 history tests, and 4 new regressions.

- [ ] **Step 4: Re-check production safety baselines**

Expected: production row counts and database/WAL timestamps are unchanged, and the general pasteboard change count is unchanged.

- [ ] **Step 5: Run the project-standard compile check**

Run:

```bash
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED` with no `AppState` Sendable warning.

- [ ] **Step 6: Review the final diff and preserve unrelated work**

Confirm `git diff --check` passes and verify the existing uncommitted light-mode/navigation work remains intact.

- [ ] **Step 7: Commit the verified stability checkpoint**

Stage only files in this plan and commit:

```bash
git commit -m "fix: isolate tests and harden shelf interactions"
```

Report the short commit hash and then begin a separate product-next-step review.
