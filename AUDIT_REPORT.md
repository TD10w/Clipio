# Clipio pre-beta product and engineering audit

Audit date: 2026-07-17

## Executive summary

**Verdict: Not ready for external beta.**

Clipio's core is coherent and the local Release build compiles, installs, launches, and remains idle at effectively 0% CPU in the short sample. The unit suite is healthy at its current scope (78 tests passed). The new shelf is separated into focused views, image previews are bounded and released deliberately, privacy pasteboard types are filtered, and the local installer is substantially safer than the older double-click installer.

Four release blockers remain:

1. Clipboard text is written verbatim to application logs and, after notification permission is granted, to macOS notifications. Both are privacy exposures for a clipboard manager.
2. The installed Release is ad-hoc signed, has no Team ID, is not notarized, contains `get-task-allow`, has Hardened Runtime disabled in the current working tree, and is rejected by Gatekeeper. It cannot be safely handed to normal external testers.
3. Paste-to-frontmost-app silently continues when Accessibility permission is missing. The current permission check does not prompt, explain, return a result, or prevent a doomed paste attempt.
4. The UI test launch argument makes `AppDelegate` return before it creates the status item, panel, clipboard observer, and shortcuts. A representative UI test failed for exactly this reason, so the most important interactions are not currently protected by runnable automation.

There are also meaningful reliability gaps: storage startup can terminate the app on a database error, saves silently discard errors, multiple-file drag-out exposes only the first file, image cache cleanup can prevent thumbnail regeneration, and the update UI is present without a configured feed.

No source behavior was changed during this audit. No real clipboard history was opened, captured, printed, or included in evidence. Visual inspection of the populated shelf was intentionally omitted to avoid exposing private history; a synthetic UI run was attempted, but the UI test harness currently prevents the interface from being created.

## Build and environment

| Item | Result |
|---|---|
| Tested macOS | macOS 26.4.1, build 25E253 |
| Tested Xcode | Xcode 26.5, build 17F42 |
| Declared minimum macOS | 14.0 |
| Branch | `master`, 21 commits ahead of `origin/master` at audit start |
| Commit | `0ddd021251fea381cacc213a3f2983e60569eca5` (`Add local release installer`) |
| Existing user change | `Clipio.xcodeproj/project.pbxproj` was already modified. It was preserved. The diff enables Hardened Runtime for Debug and disables it for Release. |
| App version | 2.6.1 (build 60) |
| Tested architecture | arm64; the built app is a thin arm64 binary |
| Release build | Succeeded with unsigned build command; intended ad-hoc signed local workflow also succeeded |
| Unit tests | 78 passed, 0 failed |
| Representative UI test | 1 failed: status item never appears because test mode skips app setup |
| Required Debug compile-check | Succeeded with the project-prescribed command after the sandboxed attempt was rerun with access to Xcode/SwiftPM caches |
| Install and launch | Intended local installer succeeded; `/Applications/Clipio.app` launched and remained running |
| Short idle sample | 68,992 KB RSS and 0.0% CPU after about 19 seconds; this is a smoke sample, not a performance study |
| Gatekeeper | Rejected (`spctl` exit 3) |

### Compiler and dependency observations

Package resolution succeeded outside the restricted sandbox. The resolved packages included Sparkle 2.6.4, KeyboardShortcuts 2.0.2, Defaults 8.2.0, Settings 3.1.1, LaunchAtLogin 1.1.0, Fuse 1.4.0, Sauce 2.4.1, SwiftHEXColors 1.4.1, and swift-log 1.6.4.

The Release compiler reported three Swift concurrency warnings:

- `Maccy/AppDelegate.swift:237`: capture of non-Sendable `self` in an `@Sendable` closure.
- `Maccy/Observables/HistoryItemDecorator.swift:248`: the same class of warning.
- `Maccy/Observables/HistoryItemDecorator.swift:258`: the same class of warning.

Xcode also warned that multiple macOS destinations matched and selected the first one. That warning is harmless locally but the build command should specify architecture/destination in a reproducible release pipeline.

The first sandboxed Release build could not resolve Swift packages because network access and some developer-service paths were restricted. The same command succeeded when rerun with the required local permissions; this was an audit-environment issue rather than a repository defect.

### Signing and distribution observations

The intended local workflow deliberately uses ad-hoc signing. The installed bundle passes `codesign --verify --deep --strict`, but its signature is not suitable for external distribution:

- signature: ad-hoc
- Team ID: not set
- Hardened Runtime: absent in the current Release build
- entitlement: `com.apple.security.get-task-allow = true`
- sandbox: enabled
- Gatekeeper assessment: rejected
- notarization: not present
- architecture: arm64 only in the audited build

This is acceptable as a local developer convenience. It is not an external beta release process.

### Exact commands used

```sh
git status --short --branch
git diff -- Clipio.xcodeproj/project.pbxproj
git branch --show-current
git rev-parse HEAD
sw_vers
xcodebuild -version

xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Release \
  -derivedDataPath /tmp/clipio-audit-deriveddata build CODE_SIGNING_ALLOWED=NO

xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO

scripts/release-local.sh --build-only \
  --derived-data /tmp/clipio-audit-signed-release

xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/clipio-audit-tests test \
  -only-testing:ClipioTests CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES

xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug \
  -derivedDataPath /tmp/clipio-audit-ui-tests test \
  -only-testing:ClipioUITests/MaccyUITests/testPopupWithMenubar \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES

scripts/release-local.sh --derived-data /tmp/clipio-audit-signed-release

pgrep -fl '/Applications/Clipio.app/Contents/MacOS/Clipio'
ps -axo pid=,rss=,%cpu=,etime=,command=
codesign --verify --deep --strict --verbose=2 /Applications/Clipio.app
codesign -dv --verbose=4 /Applications/Clipio.app
codesign -d --entitlements :- /Applications/Clipio.app
spctl --assess --type execute --verbose=4 /Applications/Clipio.app
file /Applications/Clipio.app/Contents/MacOS/Clipio
```

## Architecture overview

Clipio is a menu-bar macOS application built with SwiftUI plus AppKit window management.

- `AppDelegate` owns startup, status item creation, shortcut registration, the shelf panel, and the hover preview panel.
- `FloatingPanel` is a fixed-size, top-centered, non-activating panel. It closes on focus loss unless a drag is active and uses generation checks to avoid stale animation completions.
- `Clipboard` polls `NSPasteboard.general` every 500 ms, converts supported pasteboard representations into `HistoryItem` models, restores selected content to the pasteboard, and synthesizes Command-V for paste.
- `History` owns the in-memory decorated list, duplicate handling, pin ordering, filtering/search, retention limits, and SwiftData writes.
- `Storage` owns a single main-actor SwiftData `ModelContainer` at `Application Support/Maccy/Storage.sqlite` inside Clipio's sandbox container.
- `HistoryListView` and `CardItemView` implement the horizontal shelf, keyboard selection, card actions, and drag providers.
- `HistoryItemDecorator` owns derived text, thumbnail generation, large preview generation, and preview memory release.
- `PreviewPopupPanel` is a second AppKit panel positioned below the shelf.
- App-wide state is shared through `AppState.shared`, `Clipboard.shared`, `History.shared`, and `Storage.shared`. This keeps the app small, but tightly couples startup and makes isolated UI testing difficult.

Data remains local in reviewed application code. No application-owned network upload of clipboard data was found. Sparkle is linked for update checks, and settings can open external links; those are the main network-capable paths. Absence of an upload call is not a formal network security proof.

## Core feature matrix

The results below distinguish code-backed evidence from genuine runtime verification. “Requires manual verification” is used where automation would expose private clipboard history or where the current UI harness is broken.

| Feature | Result | Evidence | Severity | Reproduction steps | Recommended action |
|---|---|---|---|---|---|
| First launch | Requires manual verification | Synthetic UI launch skips all app setup; normal installed app used existing local state | P1 coverage gap | Test on a fresh macOS user account or disposable VM | Add a deterministic fresh-profile UI smoke test |
| Normal launch | Pass with concern | Intended installer launched PID 17863; process stayed alive | P1 distribution concern | Run `scripts/release-local.sh`; confirm menu-bar item | Keep smoke test; fix distributable signing |
| Quit and reopen | Requires manual verification | Installer quit/relaunch path ran once; repeated user flow not automated | P2 | Quit from Clipio, reopen from Applications three times | Add launch/quit UI smoke test |
| Launch at login | Requires manual verification | LaunchAtLogin control and dependency exist; no end-to-end test | P2 | Enable, log out/in on a test account, confirm one instance | Test on a disposable account and prevent duplicate instances |
| Repeated shelf open/close | Requires manual verification | Panel has guarded animations; UI harness cannot create it | P1 coverage gap | Press global shortcut 20 times slowly, then 20 times rapidly | Repair UI harness and add state-cycle test |
| Open while another app is active | Requires manual verification | Non-activating panel and frontmost-app logic reviewed only | P1 | Focus TextEdit, open shelf, choose Paste | Verify focus returns and paste target remains correct |
| Wake from sleep/inactivity | Requires manual verification | 500 ms timer uses common run-loop mode; no wake test | P2 | Sleep Mac for five minutes, wake, copy a synthetic token | Confirm first post-wake capture and low idle CPU |
| Plain text capture | Pass | Unit coverage and capture path support `.string` | — | Copy `CLIPIO-AUDIT-PLAIN-001` | Retain regression test |
| Long text capture | Pass with concern | Title is capped and payload stored; no size limit or large-item benchmark | P2 | Copy 1 MB synthetic text, reopen/search it | Establish supported size and performance budget |
| Rich text | Pass with concern | RTF types supported and unit tested; parsing can be synchronous | P2 | Copy styled synthetic text from TextEdit | Add realistic RTF round-trip/performance test |
| Browser HTML | Pass with concern | HTML supported and optimized title stripping exists; no browser end-to-end test | P2 | Copy a synthetic formatted browser block | Add fixture-based and manual round-trip test |
| URLs | Pass | Stored as supported text and rendered as text card | — | Copy `https://example.invalid/clipio-audit` | Retain fixture test |
| Images | Pass with concern | Unit tests cover image content; thumbnail/preview paths exist | P2 | Copy a generated non-private PNG | Fix cache regeneration and manually verify drag |
| Screenshots | Requires manual verification | Same image path, but Screen Capture end-to-end not automated | P2 | Capture a small synthetic test window | Confirm card, preview, copy, and drag |
| Single Finder file | Pass with concern | Multi-file pasteboard write exists; drag provider checks reachability | P2 | Copy a disposable file and paste/drag it | Add temporary-file integration test |
| Multiple Finder files | Pass with concern | Clipboard restore writes every file URL; card drag exposes only `.first` | P2 | Copy two disposable files; paste, then drag card | Define multi-file drag UX and implement as a group |
| Duplicate entries | Pass | Unit tests pass; duplicate path merges counts and preserves pin | P0 privacy concern | Copy the same synthetic text twice | Remove content from duplicate log message |
| Rapid successive copying | Requires manual verification | 500 ms polling can coalesce changes between polls by design | P2 | Copy ten numbered values at 100 ms and 600 ms intervals | Document capture cadence and benchmark expected loss |
| Very large items | Requires manual verification | No payload size cap; model work and persistence are main-actor driven | P1 risk | Copy synthetic 10 MB text and a 50 MB image in a test profile | Add limits, timing metrics, and graceful rejection |
| Empty/unsupported content | Pass | Guard paths ignore absent/unsupported representations | — | Put a custom unsupported type on a synthetic pasteboard | Keep unit coverage |
| Concealed/transient types | Pass with concern | Default ignored types and tests exist; password-manager matrix not end-to-end tested | P0 if regressed | Use synthetic concealed/transient pasteboard items only | Add explicit fixtures for every default ignored type |
| Password-manager content | Not testable automatically | Real secrets were correctly excluded from audit; app-name/type behavior varies | P0 | Use a fake password entry in a disposable vault/profile | Publish supported-manager privacy tests |
| Sensitive persistence | Pass with concern | Ignored types are skipped, but ordinary sensitive text is intentionally persisted | P0 expectations | Copy synthetic secret with and without concealed type | Add privacy onboarding, clear-history control, retention guidance |
| Data leaving the Mac | Pass with concern | No clipboard upload code found; Sparkle remains network-capable | P0 | Observe network in a disposable test while copying fixtures | Add documented privacy statement and periodic network audit |
| Clipboard content in logs | **Fail** | Unit test output printed synthetic clipboard titles verbatim | **P0** | Copy `CLIPIO-AUDIT-LOG-SECRET`, inspect Clipio logs | Log opaque IDs/counts only; mark interpolations private if retained |
| Clipboard content in notifications | **Fail** | `Notifier.notify(body: item.title)` runs on capture and selection | **P0** | Allow notifications; copy a synthetic secret; inspect banner/Notification Center | Default off; never include clip contents without explicit opt-in |
| Permission denied | **Fail** | `Accessibility.check()` does nothing when trust is absent; paste continues | **P1** | Remove Accessibility permission; invoke Paste action | Return a result, explain permission, and do not simulate keys |
| Global shortcut opens shelf | Requires manual verification | Shortcut registration exists; representative UI test cannot reach it | P1 coverage gap | Configure shortcut and invoke from another app | Repair UI harness; add smoke test |
| Second shortcut closes shelf | Requires manual verification | Toggle logic reviewed, not runtime-verified | P1 coverage gap | Press shortcut twice from TextEdit | Add UI test for visible/hidden states |
| Click outside closes shelf | Requires manual verification | Resign-key and mouse monitoring paths exist | P2 | Open shelf, click another app and desktop | Verify normal and drag-in-progress behavior |
| Search | Pass | Unit suite covers exact/regex/fuzzy filtering; 200 ms throttle exists | — | Search unique synthetic prefixes and substrings | Add UI-level selection/search test |
| Clear search | Requires manual verification | Search binding/clear behavior reviewed only | P3 | Type query, clear it, confirm full list/selection | Add UI test |
| Arrow-key navigation | Requires manual verification | Command handling exists; no working UI automation | P2 | Traverse first-to-last and back | Add boundary and empty-state UI tests |
| First/last item navigation | Requires manual verification | Index guards reviewed | P2 | Navigate beyond both ends | Confirm no wrap unless intentionally specified |
| Return to copy | Requires manual verification | Keyboard command routes to copy; notification leak remains | P1 | Select synthetic card and press Return | Verify pasteboard types and remove notification content |
| Option-Return paste | Requires manual verification | Simulated paste implemented; Accessibility denial is silent | P1 | Test with permission granted and denied | Add permission-aware integration flow |
| Command-number shortcuts | Requires manual verification | Shortcut badges/actions exist; no runtime automation | P2 | Test Command-1 through visible limit | Add UI tests for pinned/unpinned ordering |
| Reselect same card | Requires manual verification | Selection/copy paths reviewed | P3 | Copy selected card twice | Confirm intended notification/count behavior |
| Pin/unpin | Pass | Unit coverage exists and model ordering logic reviewed | — | Pin and unpin synthetic items | Add UI action/VoiceOver test |
| Pinned ordering | Pass | History sort and unit coverage exist | — | Pin items in different order and relaunch | Add persistence-level ordering test if absent |
| Delete history item | Pass with concern | Delete code and unit tests exist; UI confirmation/undo not present | P2 UX risk | Delete a disposable synthetic item | Confirm irreversible behavior is clearly signaled |
| Empty history | Requires manual verification | Shelf can render no cards, but there is no explanatory empty state | P3 | Clear disposable test profile history | Add a small privacy-safe empty-state message |
| Drag image | Requires manual verification | PNG normalization path exists; project notes say it is occasionally flaky | P2 | Drag generated PNG into Finder, Notes, and Preview twice | Add integration coverage where possible; collect destination failures |
| Drag single file | Requires manual verification | Real reachable URL becomes `NSItemProvider(contentsOf:)` | P2 | Drag a disposable file into Finder | Verify sandbox access and copy/move semantics |
| Drag text | Requires manual verification | UTF-8 provider path exists | P2 | Drag synthetic text into TextEdit | Verify Unicode and multiline content |
| Missing/moved file | **Fail** | Unreachable file falls through to plain-text representation without explanation | P2 | Copy file, move/delete it, drag its card | Show unavailable state and prevent misleading text drag |
| Inaccessible file | Requires manual verification | Reachability/provider failure falls back to text | P2 | Remove permission from disposable file, drag | Show actionable unavailable state |
| Multiple drag attempts | Requires manual verification | Drag state resets through mouse-up monitors | P2 | Drag/cancel the same card five times | Verify `isDragging` always resets |
| Cancel drag | Requires manual verification | Reset relies on mouse-up delivery and delay | P2 | Start drag and press Escape/release over shelf | Add deterministic reset on drag session end |
| Large-history scrolling | Requires manual verification | Default cap limits unpinned history; no frame-time evidence | P2 | Seed 1,000 synthetic text/image fixtures in test profile | Measure frame time and memory |
| Many images | Requires manual verification | Thumbnail/preview bounding exists; cleanup bug found | P2 | Seed 200 generated images, hover all, recheck RSS | Fix regeneration, then use Instruments |
| Many HTML clips | Requires manual verification | Optimized title path exists; no benchmark | P2 | Seed 500 synthetic HTML fixtures | Measure open/search latency |
| Large-history search | Pass with concern | Search tested functionally, capped to 5,000 candidates; no timing budget | P2 | Search a 5,000-item synthetic fixture store | Add signpost and performance test |
| Repeated open/close stability | Requires manual verification | State guards exist; no runtime stress result | P2 | Toggle 100 times and watch memory/input | Add UI stress test |
| Preview memory release | Pass with concern | Large preview is explicitly cleared on hide; no leak measurement | P2 | Hover 100 image cards, compare RSS after closing | Run Allocations/Leaks after cache fix |
| Idle CPU | Pass with concern | One short sample showed 0.0% CPU | P2 evidence limit | Leave app idle 15 minutes and sample | Add longer energy/CPU measurement |
| Shelf-visible CPU | Requires manual verification | Not measured to avoid opening private history | P2 | Use synthetic profile; leave shelf visible for five minutes | Measure with Instruments/Activity Monitor |
| Main-thread blocking | Pass with concern | OCR, duplicate scanning, and persistence have main-thread risk; no hang reproduced | P1 risk | Profile large image OCR and large duplicate history | Move bounded heavy work off main actor safely |

## Issues by priority

### P0 — Clipboard contents are written verbatim to logs

- **Category:** Confirmed defect — privacy exposure
- **Priority:** P0
- **Confidence:** High
- **Affected files:** `Maccy/Observables/History.swift:137`, `Maccy/Observables/History.swift:165`
- **Reproduction:** Launch a development/test build; copy `CLIPIO-AUDIT-LOG-SECRET-001`; inspect Xcode/test output or local Clipio logs. Copy it again to exercise duplicate handling.
- **Expected:** Logs contain operational metadata only, never clipboard payload or title text.
- **Actual:** Insert and duplicate messages interpolate `item.title` verbatim.
- **Evidence:** The unit test run printed synthetic clipboard titles in its output. Source inspection confirms both log statements.
- **Likely root cause:** A debugging message labels the value as an ID, but uses the user-derived title.
- **Smallest safe fix:** Replace the title with a non-content event name and safe metadata such as representation count, content category, and an ephemeral opaque identifier. Do not hash the content; low-entropy clipboard values can be guessed from hashes.
- **Regression risk:** Low. Only diagnostics change.
- **Verification:** Copy a unique synthetic marker, exercise insert and duplicate paths, then assert that the marker is absent from captured logs.

### P0 — Notifications expose clipboard contents and authorization is requested from the capture path

- **Category:** Confirmed defect — privacy exposure
- **Priority:** P0
- **Confidence:** High
- **Affected files:** `Maccy/Notifier.swift:7-38`, `Maccy/Observables/History.swift:171-174`, `Maccy/Clipboard.swift:118-120`
- **Reproduction:** Grant Clipio notification permission. Copy `CLIPIO-AUDIT-NOTIFICATION-SECRET-001` or reselect that card. Inspect the banner and Notification Center.
- **Expected:** A clipboard manager should not place copied content on banners, lock-screen previews, or persistent Notification Center history by default.
- **Actual:** The clip title is used as the notification body for new capture and re-selection. Authorization is requested from `notify`, so normal copying triggers the permission request.
- **Evidence:** Direct source call chain to `Notifier.notify(body: item.title)`; notification content assigns that body when alerts are enabled.
- **Likely root cause:** Maccy-era copy feedback reused the content title as a convenient confirmation message.
- **Smallest safe fix:** Remove content bodies. Prefer no notification at all by default; if feedback is retained, make it an explicit setting and use a generic message such as “Copied from Clipio.” Do not request authorization until the user enables that setting.
- **Regression risk:** Low to medium because notification/sound expectations change.
- **Verification:** Deny and allow notifications in clean test accounts; capture/reselect a synthetic marker; assert it never appears in notification database/UI.

### P1 — Release artifacts are not distributable to external testers

- **Category:** Confirmed defect — release engineering / external testing blocker
- **Priority:** P1
- **Confidence:** High
- **Affected files:** `scripts/release-local.sh`, `Clipio.xcodeproj/project.pbxproj`, signing configuration, `Maccy/Maccy.entitlements`
- **Reproduction:** Run the intended installer, then run `codesign -dv --verbose=4`, dump entitlements, and run `spctl --assess --type execute --verbose=4 /Applications/Clipio.app`.
- **Expected:** A beta artifact is Developer ID signed, uses Hardened Runtime, excludes development entitlements, is notarized/stapled, and passes Gatekeeper on a clean Mac.
- **Actual:** The app is ad-hoc signed, has no Team ID, includes `get-task-allow`, lacks Hardened Runtime in the current Release build, is arm64-only in this environment, and Gatekeeper rejects it.
- **Evidence:** `codesign`, entitlements, `file`, and `spctl` outputs recorded in Build and environment.
- **Likely root cause:** The current script was intentionally designed for safe local installation, not distribution. A pre-existing working-tree edit also swapped the Debug/Release Hardened Runtime values.
- **Smallest safe fix:** Keep the local script, add a separate archive/export/notarize pipeline using a Developer ID Application certificate, enable Hardened Runtime for Release, remove `get-task-allow`, choose supported architectures, staple the ticket, and test the exact exported zip/DMG on a clean account/Mac.
- **Regression risk:** Medium. Sparkle helpers, sandbox entitlements, and Accessibility behavior must be verified under the final signature.
- **Verification:** `codesign --verify --deep --strict`, `spctl` acceptance, `stapler validate`, clean-Mac launch, update, and paste tests.

### P1 — Accessibility denial causes silent paste failure

- **Category:** Confirmed defect — permission handling / core workflow
- **Priority:** P1
- **Confidence:** High
- **Affected files:** `Maccy/Accessibility.swift:3-10`, `Maccy/Clipboard.swift:125-150`
- **Reproduction:** Remove Clipio from System Settings → Privacy & Security → Accessibility. Open Clipio from another app and invoke the paste action.
- **Expected:** Clipio explains why permission is needed, offers the system prompt/settings route, and does not claim or attempt a successful paste until trusted.
- **Actual:** `Accessibility.check()` returns without action, and `Clipboard.paste()` continues posting synthetic key events.
- **Evidence:** Direct source inspection; there is no result, prompt option, error state, or guard.
- **Likely root cause:** Permission handling was reduced to a stub while the paste implementation continued assuming trust.
- **Smallest safe fix:** Make the check return `Bool`; prompt intentionally through `AXIsProcessTrustedWithOptions` when the user first requests paste; show one concise explanation; abort simulated paste when denied; retain copy-only behavior.
- **Regression risk:** Medium because permission prompts are stateful and must not become repetitive.
- **Verification:** Automated unit test around the decision layer plus manual clean-account tests for not determined, denied, granted, revoked, and re-granted states.

### P1 — UI test mode disables the UI it is supposed to test

- **Category:** Confirmed defect — test infrastructure
- **Priority:** P1
- **Confidence:** High
- **Affected files:** `MaccyUITests/MaccyUITests.swift:49`, `Maccy/RuntimeEnvironment.swift:3-6`, `Maccy/AppDelegate.swift:71-90` and the second testing guard later in launch
- **Reproduction:** Run the representative UI test command listed above.
- **Expected:** The test app launches with isolated storage and deterministic fixtures while still creating the status item, shelf, commands, and testable interface.
- **Actual:** The test app passes `enable-testing`; `RuntimeEnvironment.isTesting` becomes true; AppDelegate returns before creating the application surface. `testPopupWithMenubar` failed because the status item never appeared.
- **Evidence:** 1 UI test executed, 1 failed; source guards explain the failure.
- **Likely root cause:** A unit-test isolation switch was shared with the UI-test runtime and later expanded into an early startup exit.
- **Smallest safe fix:** Split “use in-memory fixture storage” from “skip app startup.” Give UI tests a dedicated argument that injects synthetic history and disables real pasteboard/notifications without suppressing the interface.
- **Regression risk:** Medium. Tests must never read or mutate the user's real clipboard/history.
- **Verification:** Run the entire UI suite on a disposable test profile; assert it uses a private pasteboard/store and creates the status item/shelf.

### P1 — Database errors can crash startup or silently lose persistence

- **Category:** Confirmed error-path defect and reliability risk
- **Priority:** P1
- **Confidence:** High for error handling; medium for real-world incidence
- **Affected files:** `Maccy/Storage.swift:18-33`, `Maccy/Observables/History.swift:135-150` and other `try?` persistence calls
- **Reproduction:** On a disposable profile, make the SwiftData store unreadable/corrupt or force `ModelContext.save()` to fail.
- **Expected:** Clipio preserves the original store, explains recovery options, and never pretends a clip was safely persisted after a failed save.
- **Actual:** Container initialization calls `fatalError`; save errors are commonly discarded with `try?`.
- **Evidence:** Direct source inspection. Destructive corruption testing was intentionally not run against user data.
- **Likely root cause:** Compact singleton storage code has no explicit recovery/error state.
- **Smallest safe fix:** Add a small storage error boundary: log non-sensitive error metadata, present a recovery-safe state, preserve/backup the failing store, and propagate save failures so UI state cannot imply persistence succeeded.
- **Regression risk:** Medium to high because migration and recovery touch user history. Implement only with fixture stores and backup tests.
- **Verification:** Tests for unreadable store, invalid schema/migration, disk-full save, recovery cancel, recovery success, and preservation of the original database.

### P1 — Update controls are present without a configured Clipio update feed

- **Category:** Confirmed release/product integration defect
- **Priority:** P1
- **Confidence:** High
- **Affected files:** `Maccy/Info.plist`, updater/settings code, bundled `appcast.xml`
- **Reproduction:** Inspect the built Info.plist for `SUFeedURL`, then use Settings → Check for Updates.
- **Expected:** The beta either has a signed Clipio Sparkle feed and verified update package, or hides/disables update controls until that pipeline exists.
- **Actual:** No `SUFeedURL` is configured. The repository's bundled appcast is stale Maccy metadata and is not a valid Clipio release feed.
- **Evidence:** Built Info.plist has no feed URL; source does not provide one; bundled appcast references old Maccy release material.
- **Likely root cause:** Updater UI survived the fork while release infrastructure did not.
- **Smallest safe fix:** For the first external beta, hide update controls unless a real feed is configured. Before enabling, create signed Clipio artifacts, EdDSA signatures, a HTTPS appcast, rollback policy, and clean-Mac update tests.
- **Regression risk:** Medium to high once auto-update is enabled; low if controls are temporarily hidden.
- **Verification:** Upgrade from beta N to N+1 and test signature failure, interrupted download, downgrade prevention, relaunch, and data preservation.

### P2 — Multi-file drag-out exposes only the first file

- **Category:** Confirmed defect — drag and drop
- **Priority:** P2
- **Confidence:** High
- **Affected files:** `Maccy/Views/CardItemView.swift:241-282`
- **Reproduction:** Copy two disposable Finder files into one history item, then drag the card to Finder.
- **Expected:** The drag represents both files, or the UI explicitly states that only one can be dragged.
- **Actual:** The provider uses `fileURLs.first` and returns a single item provider.
- **Evidence:** Direct source inspection. Clipboard restoration separately supports multiple file URLs, so copy/paste and drag behavior differ.
- **Likely root cause:** SwiftUI `draggable` is currently modeled as one provider per card.
- **Smallest safe fix:** Decide the supported behavior first. If multi-file drag is required, use an AppKit drag session or transferable representation capable of multiple items. Do not silently discard the rest.
- **Regression risk:** Medium because drag sessions are already the least reliable UI path.
- **Verification:** Drag 1, 2, and 20 files to Finder and a compatible third-party app; verify names, count, and source preservation.

### P2 — Missing or inaccessible file drag silently becomes text

- **Category:** Confirmed defect — drag and drop / misleading fallback
- **Priority:** P2
- **Confidence:** High
- **Affected files:** `Maccy/Views/CardItemView.swift:246-281`
- **Reproduction:** Copy a disposable file, move/delete it or remove access, then drag the history card.
- **Expected:** The card indicates that the original file is unavailable and offers a clear recovery/removal action.
- **Actual:** Failed reachability/provider creation falls through to a UTF-8 text provider, so the destination receives text rather than the file.
- **Evidence:** Direct control-flow inspection.
- **Likely root cause:** Text is the generic final drag representation without a distinct file-error state.
- **Smallest safe fix:** If the item contains file URLs but none can be represented, return an unavailable drag state and surface a short message; do not reclassify it as text.
- **Regression risk:** Low to medium.
- **Verification:** Test deleted, moved, permission-denied, network-volume-offline, and restored-file cases.

### P2 — Image cache cleanup can permanently suppress thumbnail regeneration

- **Category:** Likely defect — state/task lifecycle
- **Priority:** P2
- **Confidence:** High from control flow; runtime reproduction still required
- **Affected files:** `Maccy/Observables/HistoryItemDecorator.swift:155-170` and thumbnail task guards
- **Reproduction:** Load image cards, change the image height preference that invokes `cleanupImages()`, and revisit the shelf.
- **Expected:** Existing tasks are canceled, cached images are released, and thumbnails regenerate at the new size.
- **Actual:** `cleanupImages()` clears images but does not set `thumbnailImageGenerationTask` or `previewImageGenerationTask` to `nil`. The “task already exists” guard can then suppress regeneration.
- **Evidence:** Direct task lifecycle inspection; `releasePreviewImage()` correctly nils its task, showing the missing reset in `cleanupImages()`.
- **Likely root cause:** Cleanup was expanded to cancellation without resetting task state.
- **Smallest safe fix:** Nil canceled task references on the main actor, then request regeneration where appropriate. Guard against stale canceled tasks writing results.
- **Regression risk:** Medium because image generation is asynchronous.
- **Verification:** Add a decorator test for generate → cleanup → regenerate, plus rapid setting changes and deletion during generation.

### P2 — Large clipboard items can perform unbounded work on the main actor

- **Category:** Maintainability/performance risk
- **Priority:** P2 (promote to P1 if profiling reproduces visible hangs)
- **Confidence:** Medium
- **Affected files:** `Maccy/Clipboard.swift`, `Maccy/Models/HistoryItem.swift`, `Maccy/Observables/History.swift`, `Maccy/Observables/HistoryItemDecorator.swift`
- **Reproduction:** In a disposable test profile, copy a 10 MB rich-text/HTML clip, a large image requiring OCR, and repeatedly duplicate items in a 5,000-item store while recording a Time Profiler trace.
- **Expected:** Clipboard polling, shelf animation, and keyboard input remain responsive within a documented size budget.
- **Actual:** There is no size cap or benchmark. SwiftData work and duplicate discovery are main-actor centered; OCR/title derivation can execute expensive work from main-actor-created tasks; duplicate detection fetches broadly and filters in memory.
- **Evidence:** Source inspection. No user-visible hang was claimed because a safe synthetic performance profile was not completed.
- **Likely root cause:** The original lightweight assumptions were reasonable for a small default history but are not enforced as input bounds.
- **Smallest safe fix:** First add signposts and synthetic benchmarks. Then impose explicit item limits and move only measured expensive transformations off-main using immutable data, returning results safely to the model actor.
- **Regression risk:** High if concurrency is changed broadly. Measure before refactoring.
- **Verification:** Performance baselines for capture latency, shelf open time, search latency, RSS, and main-thread stalls at supported limits.

### P2 — Installer rollback is incomplete, and a second legacy installer is destructive

- **Category:** Confirmed release-maintenance risk
- **Priority:** P2 for local development; P1 if offered to testers
- **Confidence:** High
- **Affected files:** `scripts/release-local.sh:67-96`, `Install Clipio.command:18-34`
- **Reproduction:** Review failure handling or simulate `ditto`/post-copy signature failure in a disposable destination.
- **Expected:** One documented installer preserves and restores the last valid app for every failed install stage.
- **Actual:** The newer script restores only when the destination does not exist; a partial destination can prevent backup restoration. The older command force-kills Clipio, recursively deletes the installed app, copies an unsigned build, and has no rollback.
- **Evidence:** Direct shell control-flow inspection. No destructive failure injection was run against `/Applications`.
- **Likely root cause:** The safer script was added while the older convenience command remained; rollback assumes copy failure leaves no destination.
- **Smallest safe fix:** Deprecate the old command in documentation. Install to a temporary sibling path, validate there, atomically replace the destination, and restore backup on every unsuccessful exit after removing only the validated partial target.
- **Regression risk:** Medium; test exclusively with temporary directories before `/Applications`.
- **Verification:** Automated tests for no prior app, valid prior app, build failure, copy failure, signature failure, launch failure, spaces in paths, and backup restoration.

### P2 — Important interactions lack accessibility and deterministic keyboard/UI coverage

- **Category:** Likely defect / testability and accessibility risk
- **Priority:** P2
- **Confidence:** Medium
- **Affected files:** `Maccy/Views/CardItemView.swift`, `Maccy/Views/HistoryListView.swift`, settings views, `MaccyUITests`
- **Reproduction:** Run VoiceOver and Full Keyboard Access through open, search, select, pin, delete, copy, paste, preview, settings, and quit.
- **Expected:** Every action has a discoverable label/value/hint, visible keyboard focus, logical reading order, and no parent element hiding child actions.
- **Actual:** No functioning accessibility UI suite exists, and custom card/overlay interactions depend heavily on pointer hover and keyboard event handling. A complete runtime audit was not possible without synthetic UI isolation.
- **Evidence:** Source/test review and failed UI harness. This is not presented as proof that every control is inaccessible.
- **Likely root cause:** The card redesign prioritized compact custom interaction before accessibility regression coverage.
- **Smallest safe fix:** After repairing the harness, inventory accessibility elements and add identifiers/labels only where needed. Verify VoiceOver manually before restructuring views.
- **Regression risk:** Low for labels, medium for changing element grouping/focus behavior.
- **Verification:** Accessibility Inspector audit plus keyboard-only and VoiceOver checklist on a synthetic profile.

### P3 — Empty history has no explanatory state

- **Category:** Product/UX suggestion, not a correctness bug
- **Priority:** P3
- **Confidence:** High
- **Affected files:** `Maccy/Views/HistoryListView.swift`
- **Reproduction:** Open Clipio with an empty disposable store.
- **Expected:** A short message explains that copied items will appear locally and how to close/open the shelf.
- **Actual:** The horizontal content area has no cards and no dedicated explanation.
- **Evidence:** View hierarchy review; runtime visual confirmation remains manual.
- **Likely root cause:** The redesign focused on populated history.
- **Smallest safe fix:** Add a compact empty state using the existing typography/material; no onboarding flow is needed.
- **Regression risk:** Low.
- **Verification:** Snapshot/manual check at the supported shelf size, increased text size, light/dark mode.

### P3 — Fork documentation and update metadata still mix Clipio and Maccy

- **Category:** Maintainability/documentation issue
- **Priority:** P3
- **Confidence:** High
- **Affected files:** `README.md`, `appcast.xml`, About/settings links, test names and comments
- **Reproduction:** Read installation/update/about documentation and inspect bundled metadata.
- **Expected:** Clipio-specific identity, support, release, and privacy information is unambiguous.
- **Actual:** Some badges/downloads, appcast data, links, names, and instructions still point to Maccy or the fork source.
- **Evidence:** Repository search and metadata inspection.
- **Likely root cause:** Intentional fork history plus incomplete release-document migration.
- **Smallest safe fix:** Update only user-facing release/support/privacy references now; preserve upstream credit and license clearly.
- **Regression risk:** Low.
- **Verification:** Search built resources and repository docs for stale release URLs/names; manually check About and Settings links.

## Manual test checklist

Use a disposable macOS account or VM with no personal clipboard history. Create only synthetic items. Do not use a real password manager vault.

### Before launching

- [ ] Confirm the artifact passes Gatekeeper on a clean Mac and shows the expected developer identity.
- [ ] Confirm the app version/build and architecture(s).
- [ ] Record whether Accessibility and Notifications are not determined, denied, or granted.
- [ ] Create a folder containing two disposable text files, one PNG, and one file that can be moved/deleted.
- [ ] Prepare synthetic values such as `CLIPIO-AUDIT-TEXT-001`; never use real secrets.

### Lifecycle and permissions

- [ ] First launch shows one Clipio menu-bar item and no crash/error.
- [ ] Open/close the shelf 20 times, then press the shortcut rapidly 20 times.
- [ ] Quit and reopen three times; confirm history and pins persist.
- [ ] Enable launch at login, log out/in, and confirm exactly one process/menu item.
- [ ] Deny Accessibility and try paste: Clipio should explain and fail safely while copy still works.
- [ ] Grant, revoke, and re-grant Accessibility; repeat paste each time.
- [ ] Sleep/wake the Mac, then copy a synthetic item and confirm it appears once.

### Clipboard and shelf

- [ ] Copy plain, multiline, 1 MB, RTF, browser HTML, URL, PNG, screenshot, one file, and two files.
- [ ] Copy a duplicate and confirm count/order/pin behavior.
- [ ] Copy ten numbered values more slowly than the 500 ms poll interval and confirm all; separately document expected behavior for faster copies.
- [ ] Test a synthetic concealed and transient pasteboard fixture; confirm it is absent after relaunch.
- [ ] Search exact text, fuzzy text, regex if enabled, no-result text, then clear search.
- [ ] Navigate to first/last items with arrows; test empty history.
- [ ] Test Return, paste shortcut, every visible Command-number shortcut, reselect, pin/unpin, delete, Settings, and Quit.
- [ ] Inspect Console and Notification Center for the unique synthetic markers; none should appear after privacy fixes.

### Drag and preview

- [ ] Drag text into TextEdit twice and cancel once.
- [ ] Drag a PNG into Finder, Notes, and Preview twice each.
- [ ] Drag one file and then a two-file history item into Finder; verify exact item count.
- [ ] Move/delete the source file and retry; confirm a clear unavailable state rather than pasted path text.
- [ ] Remove access to a disposable file and retry.
- [ ] Hover at least 100 generated image cards, close the shelf, wait one minute, and compare memory.
- [ ] Change image preview/card height and confirm every thumbnail regenerates.

### Performance and accessibility

- [ ] Seed 1,000 text items, 200 images, and 500 HTML fixtures in a disposable store.
- [ ] Measure idle CPU for 15 minutes and visible-shelf CPU for 5 minutes.
- [ ] Record shelf-open latency, search latency, scrolling smoothness, and RSS before/after preview stress.
- [ ] Run VoiceOver and Full Keyboard Access through every shelf and settings action.
- [ ] Test light/dark mode, increased text size, multiple displays, and switching the active display.
- [ ] Save crash, hang, and performance diagnostics only if they contain no clipboard payloads.

## Engineering health

### What is structured well

- The shelf, card, floating panel, and preview panel have recognizable ownership rather than living in one monolithic view.
- Clipboard representations are modeled explicitly, which supports text, rich content, images, and multiple file URLs without reimplementing the mature Maccy core.
- Image thumbnails and large previews are separated; large previews are bounded and explicitly released when hidden.
- Panel animation uses generation/state checks that reduce stale completion races during rapid toggling.
- Privacy filtering includes standard transient/concealed types and password-manager-oriented defaults, with unit coverage.
- The default history cap and 5,000-candidate search cap provide basic resource bounds.
- The newer local release script builds Release, signs, validates, backs up the existing app, installs, and launches in one reproducible command.
- The unit suite is fast enough to run routinely and passed all 78 tests in this environment.

### What will become difficult as the product grows

- Global singletons tie AppDelegate, clipboard polling, history, storage, notifications, and UI together. That makes clean dependency injection and synthetic UI startup hard, as the broken test mode demonstrates.
- Main-actor ownership extends across persistence and content processing. Large clips, OCR, and broad duplicate scans can compete with shelf animation and input.
- `History` is responsible for filtering, ordering, retention, duplicate merging, notifications, storage mutation, and UI-facing decorators. New history features will increase coupling.
- Coordinate-driven panels and hover state need explicit multi-display, Spaces, scaling, and accessibility coverage.
- Drag behavior has three representations plus panel lifetime state, but no integration tests.
- Release, signing, notarization, and Sparkle update responsibilities are not yet a single tested pipeline.

### Refactor now, before beta

Keep these changes narrow and behavior-preserving:

1. Remove clipboard payloads from logs and notifications.
2. Create a real permission decision boundary for paste.
3. Split unit-test storage isolation from UI-test startup and inject synthetic fixtures.
4. Add a storage error boundary and tests before changing the SwiftData model.
5. Correct the image task cleanup lifecycle.
6. Consolidate local installation around the safer script and harden its rollback.
7. Create a separate, documented external-release pipeline; do not overload the local installer.

### Do not touch yet

- Do not replace SwiftData or rewrite the clipboard capture core without evidence of a specific failure.
- Do not convert the small app to a broad architectural framework solely for style.
- Do not redesign the card shelf during the reliability pass.
- Do not add cloud sync, website previews, categories, or drag-to-reorder before the beta blockers are closed.
- Do not broadly introduce concurrency to “fix” performance before signposts and synthetic benchmarks identify the blocking work.
- Do not migrate the legacy-named database path merely for naming consistency; a migration risks user history and offers no immediate beta value.

## Recommended next steps

### 1. Must fix before beta

1. Remove clipboard content from logs and notification bodies; make any copy-feedback notification generic and opt-in.
2. Implement permission-aware paste behavior for not-determined, denied, granted, and revoked Accessibility states.
3. Produce a Developer ID signed, Hardened Runtime, notarized Release without `get-task-allow`; test the exported artifact on a clean Mac.
4. Hide update controls until a real Clipio feed exists, or complete and test the signed Sparkle pipeline.
5. Repair UI test startup so the shelf runs with isolated synthetic storage/pasteboard data.
6. Complete the manual checklist on a disposable account, especially copy/paste focus, drag destinations, notification privacy, and first launch.

### 2. Should fix soon

1. Add safe storage startup/save error handling and corruption/disk-full fixture tests.
2. Fix image task cleanup/regeneration and measure preview memory.
3. Define and implement honest multi-file and missing-file drag behavior.
4. Add performance signposts and supported input-size limits before optimizing.
5. Harden installer rollback and retire the destructive legacy installer.
6. Run an Accessibility Inspector, VoiceOver, keyboard-only, multi-display, sleep/wake, and launch-at-login pass.
7. Resolve the three Swift concurrency warnings before enabling stricter Swift language checking.

### 3. Safe to defer

1. Rename the internal `Maccy` scheme and legacy database subpath.
2. Split singletons further after tests provide a safe refactoring boundary.
3. Polish the empty state and remaining fork documentation.
4. Expand search beyond the current title/candidate limits if testers demonstrate a need.

### 4. Possible future features

These are not beta-readiness work and should be reconsidered only after tester evidence:

1. A privacy dashboard showing retention, excluded app/type rules, and one-click clear-history controls.
2. Optional generic copy feedback that never includes content.
3. A diagnostic export that automatically redacts clipboard payloads.
4. Better unavailable-file recovery and grouped multi-file drag.

## Audit limitations

- The audit did not open the real shelf because it could reveal the owner's private clipboard history. No screenshot of private state was taken.
- The synthetic UI route was attempted, but the UI test harness disables application setup and the representative test failed. Therefore visual layout, drag destinations, VoiceOver, multi-display behavior, focus restoration, sleep/wake, launch at login, and extended performance require the disposable-profile manual pass above.
- A short process sample is not evidence of long-term energy or memory behavior.
- Corruption, disk-full, and installer-failure injection were not run against real user data or `/Applications`; conclusions there are based on explicit error-path source inspection.
- The existing `Clipio.xcodeproj/project.pbxproj` working-tree change was preserved and treated as part of the audited Release result, not authored by this audit.
