# Clipio Beta-Readiness Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Clipio's confirmed privacy and external-beta blockers without changing the shelf design, motion, or lightweight runtime behavior.

**Architecture:** Preserve the existing singleton-based application and add only narrow test seams at the privacy, Accessibility, and UI-test boundaries. Keep local installation separate from a new fail-closed external release pipeline, and disable unfinished updater UI until a real feed exists.

**Tech Stack:** Swift 6, SwiftUI, AppKit, SwiftData, XCTest/XCUITest, swift-log, Xcode 26, zsh release scripts, Apple `codesign`, `notarytool`, `stapler`, and Gatekeeper.

## Global Constraints

- Continue supporting macOS 14.0 and later.
- Keep the Xcode scheme name `Maccy`, the app name `Clipio`, and bundle identifier `com.clipio.app`.
- Do not change shelf opening/closing animations, dimensions, layout, card behavior, or timing.
- Do not add Dropzone, music display, media controls, analytics, networking, or background services.
- Never use the owner's real clipboard history; tests use synthetic content and a named test pasteboard.
- Preserve the uncommitted project-file change until Task 4 explicitly resolves the Release Hardened Runtime value.
- Use test-first development: write each regression test, observe the expected failure, then implement the minimum fix.
- After each production task, run the focused tests, all `ClipioTests`, and the required Debug compile-check.
- Stage and commit only the files belonging to the current task; do not stage `AUDIT_REPORT.md` or unrelated user changes.

---

## File responsibility map

- `Maccy/Notifier.swift`: content-free copy sound playback only; no notification authorization or delivery.
- `Maccy/Observables/History.swift`: history operations and content-free operational logging.
- `Maccy/Clipboard.swift`: isolated pasteboard dependency, copy feedback, and permission-gated paste event posting.
- `Maccy/Accessibility.swift`: Accessibility trust query, prompt, and denied-state explanation.
- `Maccy/RuntimeEnvironment.swift`: distinct unit-test and UI-test runtime flags.
- `Maccy/AppDelegate.swift`: normal UI startup in UI-test mode while retaining unit-test startup suppression.
- `Maccy/Storage.swift`: mandatory in-memory storage for both unit and UI tests.
- `MaccyTests/HistoryTests.swift`: log redaction regression coverage.
- `MaccyTests/ClipboardTests.swift`: sound and permission-gated paste regression coverage.
- `MaccyUITests/MaccyUITests.swift`: named test pasteboard and real-interface smoke coverage.
- `Maccy/Settings/GeneralSettingsPane.swift`: first-beta settings without updater/notification controls.
- `scripts/release-beta.sh`: fail-closed archive, signing, notarization, stapling, packaging, and validation.
- `tests/release-beta-tests.sh`: release-script argument and fail-closed behavior checks that need no secrets.
- `Clipio.xcodeproj/project.pbxproj`: Release Hardened Runtime configuration only in Task 4.

---

### Task 1: Remove clipboard content from logs and notifications

**Files:**
- Modify: `Maccy/Notifier.swift`
- Modify: `Maccy/Observables/History.swift`
- Modify: `Maccy/Clipboard.swift`
- Modify: `MaccyTests/HistoryTests.swift`
- Modify: `MaccyTests/ClipboardTests.swift`

**Interfaces:**
- Produces: `Notifier.play(sound:player:)`, where `player` defaults to `NSSound.play` and accepts no clipboard-derived string.
- Produces: `History.init(logger:)`, defaulting to the production `Logger`, so tests can record emitted messages.
- Preserves: existing `History.add`, `Clipboard.copy`, item ordering, duplicate merging, pasteboard content, and sound choices.

- [ ] **Step 1: Add a failing sound-only feedback test**

Add to `MaccyTests/ClipboardTests.swift`:

```swift
func testCopyFeedbackPlaysSoundWithoutClipboardContent() {
  var playedSound: NSSound?
  let sound = NSSound(named: "Knock")

  Notifier.play(sound: sound) { receivedSound in
    playedSound = receivedSound
    return true
  }

  XCTAssertTrue(playedSound === sound)
}
```

- [ ] **Step 2: Run the focused test and observe the expected compile failure**

Run:

```sh
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/clipio-beta-task1-red test \
  -only-testing:ClipioTests/ClipboardTests/testCopyFeedbackPlaysSoundWithoutClipboardContent \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES
```

Expected: FAIL because `Notifier.play(sound:player:)` does not exist.

- [ ] **Step 3: Replace notification delivery with sound-only feedback**

Replace `Maccy/Notifier.swift` with:

```swift
import AppKit

enum Notifier {
  static func play(
    sound: NSSound?,
    player: (NSSound) -> Bool = { $0.play() }
  ) {
    guard let sound else { return }
    _ = player(sound)
  }
}
```

Change both call sites:

```swift
Notifier.play(sound: .write)
```

and:

```swift
Notifier.play(sound: .knock)
```

No call may pass `item.title` or any clipboard-derived value.

- [ ] **Step 4: Run the focused sound test and observe PASS**

Run the Step 2 command again. Expected: PASS.

- [ ] **Step 5: Add a failing log-redaction test**

In `MaccyTests/HistoryTests.swift`, define a test-only `RecordingLogHandler` backed by a reference box and construct `History` with a custom `Logger`:

```swift
func testHistoryLogsNeverContainClipboardTitle() {
  let marker = "CLIPIO-PRIVATE-MARKER-001"
  let recorder = LogRecorder()
  var logger = Logger(label: "com.clipio.tests") { _ in RecordingLogHandler(recorder: recorder) }
  logger.logLevel = .trace
  let isolatedHistory = History(logger: logger)

  isolatedHistory.add(historyItem(marker))
  isolatedHistory.add(historyItem(marker))

  XCTAssertFalse(recorder.messages.joined(separator: "\n").contains(marker))
}
```

The handler must append `message.description` to `recorder.messages` and implement the complete `LogHandler` protocol without adding production dependencies.

- [ ] **Step 6: Run the log test and observe the privacy failure**

Run:

```sh
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/clipio-beta-task1-red-log test \
  -only-testing:ClipioTests/HistoryTests/testHistoryLogsNeverContainClipboardTitle \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES
```

Expected: FAIL because the marker appears in insert or duplicate log messages.

- [ ] **Step 7: Make History logging content-free**

Change the logger property and initializer in `History`:

```swift
let logger: Logger

init(logger: Logger = Logger(label: "com.clipio.app")) {
  self.logger = logger
  // Retain the existing Defaults observation tasks unchanged.
}
```

Replace the sensitive messages with fixed text:

```swift
logger.info("Inserting clipboard item")
logger.info("Removing duplicate clipboard item")
```

- [ ] **Step 8: Run focused tests, all unit tests, and compile-check**

Expected: both focused tests PASS, all existing unit tests PASS, and build reports `BUILD SUCCEEDED`.

```sh
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/clipio-beta-task1-tests test -only-testing:ClipioTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 9: Commit only Task 1 files**

```sh
git add Maccy/Notifier.swift Maccy/Observables/History.swift Maccy/Clipboard.swift \
  MaccyTests/HistoryTests.swift MaccyTests/ClipboardTests.swift
git commit -m "fix: keep clipboard feedback private"
```

---

### Task 2: Stop Paste safely when Accessibility permission is unavailable

**Files:**
- Modify: `Maccy/Accessibility.swift`
- Modify: `Maccy/Clipboard.swift`
- Modify: `MaccyTests/ClipboardTests.swift`

**Interfaces:**
- Produces: `Accessibility.requestTrust() -> Bool` and `Accessibility.explainMissingPermission()`.
- Extends: `Clipboard.init(pasteboard:enabledPasteboardTypes:accessibilityAllowed:permissionDenied:pasteEventPoster:)` with safe production defaults.
- Changes: `Clipboard.paste()` returns `Bool` (`true` only when a paste event was posted).

- [ ] **Step 1: Add failing granted/denied paste tests**

Add tests that construct `Clipboard` with an isolated pasteboard and closures:

```swift
func testPasteDoesNotPostEventsWhenAccessibilityIsDenied() {
  var deniedWasExplained = false
  var eventWasPosted = false
  let clipboard = Clipboard(
    pasteboard: pasteboard,
    accessibilityAllowed: { false },
    permissionDenied: { deniedWasExplained = true },
    pasteEventPoster: { eventWasPosted = true }
  )

  XCTAssertFalse(clipboard.paste())
  XCTAssertTrue(deniedWasExplained)
  XCTAssertFalse(eventWasPosted)
}

func testPastePostsOneEventSequenceWhenAccessibilityIsGranted() {
  var postCount = 0
  let clipboard = Clipboard(
    pasteboard: pasteboard,
    accessibilityAllowed: { true },
    permissionDenied: { XCTFail("Permission explanation should not appear") },
    pasteEventPoster: { postCount += 1 }
  )

  XCTAssertTrue(clipboard.paste())
  XCTAssertEqual(postCount, 1)
}
```

- [ ] **Step 2: Run the two tests and observe compile failure**

Expected: FAIL because the initializer closures and Boolean return do not exist.

- [ ] **Step 3: Implement the minimal injectable paste boundary**

Store the three closures in `Clipboard`. In `paste()`:

```swift
@discardableResult
func paste() -> Bool {
  guard accessibilityAllowed() else {
    permissionDenied()
    return false
  }

  pasteEventPoster()
  return true
}
```

Move the existing CGEvent creation/posting code unchanged into a private static `postPasteEvent()` used by the production default. This preserves the exact key flags and keyboard-layout behavior.

- [ ] **Step 4: Implement Accessibility trust and explanation**

Use `AXIsProcessTrustedWithOptions` with the prompt option only from the explicit Paste path. If it returns false, show one `NSAlert` explaining that the clip is already copied and can be pasted manually; include buttons for “Open System Settings” and “Not Now.” Open:

```swift
URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
```

Do not prompt from launch, capture, Copy, or shelf-open paths.

- [ ] **Step 5: Run focused tests, all units, and compile-check**

Expected: permission tests PASS, full unit suite PASS, build succeeds.

- [ ] **Step 6: Manually verify permission states with synthetic text**

On a disposable account, test not determined, denied, granted, revoked, and re-granted. Confirm copy-only behavior always works, denial posts no Command-V, and the shelf's existing close animation is unchanged.

- [ ] **Step 7: Commit only Task 2 files**

```sh
git add Maccy/Accessibility.swift Maccy/Clipboard.swift MaccyTests/ClipboardTests.swift
git commit -m "fix: gate paste on accessibility permission"
```

---

### Task 3: Launch the real shelf in an isolated UI-test runtime

**Files:**
- Modify: `Maccy/RuntimeEnvironment.swift`
- Modify: `Maccy/Storage.swift`
- Modify: `Maccy/Clipboard.swift`
- Modify: `Maccy/AppDelegate.swift`
- Modify: `MaccyUITests/MaccyUITests.swift`
- Modify: `Maccy.xctestplan` only if the target-wide argument cannot be safely overridden in code

**Interfaces:**
- Produces: `RuntimeEnvironment.isUnitTesting`, `isUITesting`, `isTesting`, and `uiTestPasteboardName`.
- Preserves: unit tests use in-memory storage and skip application UI setup.
- Adds: UI tests use in-memory storage, a named pasteboard, full status-item/panel setup, and a no-op production paste event poster.

- [ ] **Step 1: Add failing runtime-environment unit tests**

Make runtime evaluation accept an argument array for testing:

```swift
func testUITestArgumentsUseIsolatedFullAppMode() {
  let environment = RuntimeEnvironment(arguments: ["Clipio", "enable-testing", "enable-ui-testing"])
  XCTAssertTrue(environment.isUITesting)
  XCTAssertFalse(environment.isUnitTesting)
  XCTAssertTrue(environment.usesInMemoryStorage)
  XCTAssertFalse(environment.skipsApplicationStartup)
}
```

Add the complementary unit-only case for `enable-testing` without `enable-ui-testing`.

- [ ] **Step 2: Run the runtime tests and observe compile failure**

Expected: FAIL because instance-based runtime evaluation does not exist.

- [ ] **Step 3: Implement explicit runtime modes**

Use these meanings:

```swift
struct RuntimeEnvironment {
  static let current = RuntimeEnvironment(arguments: CommandLine.arguments)
  static let uiTestPasteboardName = NSPasteboard.Name("com.clipio.ui-tests")

  let arguments: [String]
  var isUITesting: Bool { arguments.contains("enable-ui-testing") }
  var isUnitTesting: Bool { arguments.contains("enable-testing") && !isUITesting }
  var isTesting: Bool { isUnitTesting || isUITesting }
  var usesInMemoryStorage: Bool { isTesting }
  var skipsApplicationStartup: Bool { isUnitTesting }
}
```

Provide static forwarding properties if that avoids broad call-site edits.

- [ ] **Step 4: Make UI-test dependencies isolated**

- `Storage` uses `ModelConfiguration(isStoredInMemoryOnly: true)` whenever `usesInMemoryStorage` is true.
- `Clipboard.shared` uses `NSPasteboard(name: RuntimeEnvironment.uiTestPasteboardName)` in UI-test mode and `.general` otherwise.
- `Clipboard`'s default paste event poster is a no-op in UI-test mode.
- `AppDelegate` skips other-instance termination in any test mode but returns early only for unit tests.
- UI-test mode initializes the normal status item, panel, ContentView, search, and history observer.

- [ ] **Step 5: Convert UI tests from the general pasteboard to the named pasteboard**

In `MaccyUITests.swift`:

```swift
let pasteboard = NSPasteboard(name: .init("com.clipio.ui-tests"))
```

Clear it in setup/teardown, append `enable-ui-testing`, and retain synthetic UUID content. Do not read or modify `NSPasteboard.general`.

- [ ] **Step 6: Run the representative menu-bar test and observe PASS**

```sh
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/clipio-beta-task3-ui test \
  -only-testing:ClipioUITests/MaccyUITests/testPopupWithMenubar \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES
```

Expected: status item appears, the shelf opens with its normal animation, and the test passes.

- [ ] **Step 7: Add/retain critical UI regression coverage**

Run or repair tests for: status-item open, second activation close, click-outside close, search/clear, arrow boundaries, Return copy to named pasteboard, paste interception, pin/unpin, and delete. Tests must wait for the real production animation rather than disabling it.

- [ ] **Step 8: Prove real pasteboard isolation**

Record `NSPasteboard.general.changeCount` before the suite, exercise copy/paste flows through the named pasteboard, and assert the general change count is unchanged at teardown. No fixture may use personal data.

- [ ] **Step 9: Run all units, critical UI tests, and compile-check**

Expected: all units PASS, selected UI tests PASS, build succeeds.

- [ ] **Step 10: Commit only Task 3 files**

```sh
git add Maccy/RuntimeEnvironment.swift Maccy/Storage.swift Maccy/Clipboard.swift \
  Maccy/AppDelegate.swift MaccyUITests/MaccyUITests.swift Maccy.xctestplan
git commit -m "test: isolate and restore shelf ui coverage"
```

Do not stage `Maccy.xctestplan` if it did not need modification.

---

### Task 4: Add a fail-closed external-beta release pipeline

**Files:**
- Create: `scripts/release-beta.sh`
- Create: `tests/release-beta-tests.sh`
- Modify: `Clipio.xcodeproj/project.pbxproj` only to make Release `ENABLE_HARDENED_RUNTIME = YES`
- Inspect: `Maccy/Maccy.entitlements`

**Interfaces:**
- Consumes required environment variables: `CLIPIO_DEVELOPER_ID` and `CLIPIO_NOTARY_PROFILE`.
- Produces: a signed, notarized, stapled zip at an explicit output directory.
- Supports: `--validate-only /absolute/path/Clipio.app` for credential-free artifact validation.

- [ ] **Step 1: Write failing shell tests for missing credentials and invalid artifacts**

`tests/release-beta-tests.sh` must assert:

```sh
scripts/release-beta.sh --output /tmp/clipio-beta-test
# exits non-zero and names CLIPIO_DEVELOPER_ID when missing

scripts/release-beta.sh --validate-only /tmp/not-a-clipio-app
# exits non-zero and does not claim success
```

The test uses a temporary directory and never writes to `/Applications`.

- [ ] **Step 2: Run the release tests and observe failure because the script is absent**

```sh
tests/release-beta-tests.sh
```

Expected: FAIL because `scripts/release-beta.sh` does not exist.

- [ ] **Step 3: Implement argument and credential validation**

The script uses `set -euo pipefail`, accepts `--output`, `--derived-data`, and `--validate-only`, and prints secrets only by variable name, never value. Normal release mode exits before building unless both required variables are non-empty.

- [ ] **Step 4: Implement the release stages**

The normal path must, in order:

1. build/archive Release with the named Developer ID identity, manual signing, timestamping, Hardened Runtime, and `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`;
2. verify the app recursively with `codesign --deep --strict`;
3. assert bundle ID `com.clipio.app`, expected version fields, Hardened Runtime flag, Team ID presence, and absence of `get-task-allow`;
4. zip the app with `ditto -c -k --keepParent`;
5. submit the zip with `xcrun notarytool submit --keychain-profile "$CLIPIO_NOTARY_PROFILE" --wait`;
6. staple and validate the app with `xcrun stapler`;
7. require Gatekeeper acceptance with `spctl`;
8. recreate the final zip from the stapled app and print its path.

Any failed stage exits non-zero and leaves no artifact labeled successful.

- [ ] **Step 5: Resolve the existing Hardened Runtime project change narrowly**

Before editing, display the existing diff to the owner. Preserve Debug `YES` and change Release from `NO` to `YES`. Do not modify unrelated project settings.

- [ ] **Step 6: Run credential-free tests and local negative validation**

Expected: shell tests PASS; the current ad-hoc local app fails beta validation specifically for identity/runtime/notarization rather than being accepted.

- [ ] **Step 7: Run the full beta release when credentials exist**

```sh
export CLIPIO_DEVELOPER_ID
export CLIPIO_NOTARY_PROFILE
scripts/release-beta.sh --output /tmp/clipio-beta-output
```

Expected: final stapled zip path, `codesign` PASS, `stapler validate` PASS, and `spctl` accepted.

This step is blocked on the audited Mac until a valid Developer ID identity and notarization profile exist. Do not weaken validation to bypass the prerequisite.

- [ ] **Step 8: Run Release build and required Debug compile-check**

Expected: both builds succeed. Record exact signing warnings separately.

- [ ] **Step 9: Commit the release checkpoint without unrelated files**

```sh
git add scripts/release-beta.sh tests/release-beta-tests.sh Clipio.xcodeproj/project.pbxproj
git commit -m "build: add notarized beta release pipeline"
```

Only stage the intended Hardened Runtime hunk from the project file.

---

### Task 5: Hide the unfinished updater and notification settings for beta

**Files:**
- Modify: `Maccy/Settings/GeneralSettingsPane.swift`
- Modify: `Maccy/AppDelegate.swift`
- Modify: `MaccyUITests/MaccyUITests.swift`
- Inspect: `Maccy/Info.plist`

**Interfaces:**
- Removes visible Check for Updates, automatic-update, and Notifications and Sounds controls.
- Removes test-only Sparkle updater construction from app startup.
- Preserves Launch at Login and every clipboard/shelf setting.

- [ ] **Step 1: Add a failing UI test for absent beta-only controls**

Open Settings through the shelf and assert these localized controls do not exist:

```swift
XCTAssertFalse(app.buttons["Check Now"].exists)
XCTAssertFalse(app.checkBoxes["Automatically check for updates"].exists)
XCTAssertFalse(app.links["Notifications and Sounds"].exists)
```

Use actual accessibility labels from the English localization table when implementing the test.

- [ ] **Step 2: Run the focused UI test and observe failure**

Expected: FAIL because the controls currently exist.

- [ ] **Step 3: Remove updater and notification controls with the smallest view edit**

In `GeneralSettingsPane`, remove `notificationsURL`, the `SoftwareUpdater` state, updater Toggle/Button, and the notification Settings link. Keep `LaunchAtLogin.Toggle` and all remaining sections unchanged.

Remove the Debug/testing `SPUUpdater` construction from `AppDelegate` and remove the Sparkle import there if no longer used. Do not broadly remove the Sparkle package or `SoftwareUpdater.swift` in this checkpoint.

- [ ] **Step 4: Verify no feed is configured**

Build the app and run:

```sh
/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' \
  /tmp/clipio-beta-task5-build/Build/Products/Debug/Clipio.app/Contents/Info.plist
```

Expected: non-zero with “Does Not Exist.” Repository search must show no active appcast URL in production initialization.

- [ ] **Step 5: Run focused UI test, all units, critical UI tests, and compile-check**

Expected: updater-control test PASS, unit and critical UI tests PASS, build succeeds, shelf animations unchanged.

- [ ] **Step 6: Commit only Task 5 files**

```sh
git add Maccy/Settings/GeneralSettingsPane.swift Maccy/AppDelegate.swift MaccyUITests/MaccyUITests.swift
git commit -m "fix: hide unfinished beta update controls"
```

---

### Task 6: Assemble and verify the beta candidate

**Files:**
- Modify: `AUDIT_REPORT.md` only if the owner wants verification results recorded there
- No production changes are permitted in this task unless a failing acceptance test sends work back to its owning task.

**Interfaces:**
- Consumes: all five verified checkpoints.
- Produces: explicit pass/fail beta decision and manual-test record.

- [ ] **Step 1: Run the complete unit suite**

Expected: all tests PASS with no synthetic clipboard marker printed in logs.

- [ ] **Step 2: Run the critical isolated UI suite**

Expected: status item, normal pop-out/close animation, search, navigation, copy interception, paste interception, pin, and delete tests PASS without changing the general pasteboard.

- [ ] **Step 3: Run required Debug and Release builds**

Expected: `BUILD SUCCEEDED` for both configurations. Record any remaining warnings.

- [ ] **Step 4: Validate the final packaged beta artifact**

Expected: correct Developer ID, Team ID, Hardened Runtime, no `get-task-allow`, notarization/stapling valid, and Gatekeeper accepted.

- [ ] **Step 5: Complete manual clean-account checks**

Use synthetic content only. Verify first launch, normal launch, quit/reopen, launch at login, all Accessibility states, copy sounds without notifications, Console redaction, shelf open/close animation, open while another app is active, and no updater controls/network request.

- [ ] **Step 6: Make the beta decision**

Declare “Ready for external beta” only if every automated and manual acceptance criterion passes. If Developer ID/notarization is unavailable, declare the candidate blocked on release credentials rather than distributing the ad-hoc app.

---

## Plan self-review

- **Specification coverage:** Tasks 1–5 map exactly to the five approved remediation areas; Task 6 covers final acceptance.
- **Animation protection:** No task edits `FloatingPanel`, `ContentView`, animation state, sizing, or timing. UI tests wait for production motion rather than replacing it.
- **Privacy protection:** Tests use a named synthetic pasteboard and fixed markers; the general pasteboard and persistent store are excluded from UI-test dependencies.
- **Lightweight constraint:** No new runtime service, polling loop, network client, framework, or general dependency-injection system is introduced.
- **External prerequisite:** Task 4 remains fail-closed without a Developer ID certificate and notarization profile; no bypass is allowed.
- **Deferred features:** Dropzone, music display, media controls, and other utilities remain outside this plan.
