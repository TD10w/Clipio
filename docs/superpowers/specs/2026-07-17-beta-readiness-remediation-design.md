# Clipio Beta-Readiness Remediation Design

**Date:** 2026-07-17
**Status:** Proposed for owner review
**Source:** `AUDIT_REPORT.md`

## Goal

Make Clipio safe and dependable enough for a small external beta by fixing only the confirmed privacy and release-blocking defects identified in the audit.

This work must preserve Clipio's lightweight character and existing product behavior. In particular, the shelf's pop-out and close animations must remain unchanged.

## Scope

This remediation contains five independently verifiable changes:

1. Remove clipboard content from logs and macOS notifications while preserving copy sounds.
2. Make Paste respond safely and clearly when Accessibility permission is unavailable.
3. Repair UI-test startup so the real interface can run against isolated synthetic data.
4. Add a proper signed and notarized external-beta release process.
5. Hide the unfinished update experience until a real Clipio update service exists.

Each change will be implemented, tested, compile-checked, and committed separately. A failed or rejected change must not block review or rollback of the others.

## Global constraints

- Do not change the shelf's opening animation, closing animation, dimensions, visual design, card layout, or interaction timing.
- Do not add Dropzone, music display, media controls, or other product features during beta remediation.
- Do not replace SwiftData, rewrite clipboard capture, or broadly restructure the application.
- Do not add background polling, networking, analytics, or persistent services.
- Do not inspect, log, screenshot, or test with the owner's real clipboard history.
- Automated tests must use synthetic markers and isolated storage.
- Preserve the existing uncommitted `Clipio.xcodeproj/project.pbxproj` change until the release-signing task explicitly reviews it with the owner.
- Continue supporting macOS 14.0 and later.
- Keep the Xcode scheme name `Maccy` and the application identity `Clipio` / `com.clipio.app`.
- After every production-code task, run:

  ```sh
  xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO
  ```

## Design 1: Privacy-safe copy feedback

### Required behavior

- Clipboard titles and payloads must never be included in application log messages.
- Clipio must not create macOS notifications when an item is captured or selected.
- Clipio must not request notification authorization as a side effect of copying or selecting an item.
- Existing copy feedback sounds remain available and play locally without notification permission.
- Duplicate detection, item ordering, copy counts, persistence, and pasteboard contents remain unchanged.

### Smallest safe design

Replace content-bearing history messages with fixed, content-free event messages. Replace the current notification helper with a small sound-only helper, or call the existing sound objects directly from the two feedback points. Remove the `UserNotifications` dependency from this path rather than introducing a new notification preference.

No new UI is required.

### Error handling

Sound playback is optional feedback. Failure to play a sound must not interrupt capture, copy, or selection. No clipboard-derived value may be included in an error message.

### Verification boundary

Automated tests will use a unique synthetic marker and prove that capture, duplicate handling, and re-selection do not send the marker to the logging or feedback interface. A disposable-account manual test will confirm that no banner or Notification Center entry appears and that enabled sounds still work.

## Design 2: Permission-aware Paste

### Required behavior

- Copy continues to work without Accessibility permission.
- Paste checks Accessibility trust only when the user requests Paste.
- If permission is granted, Clipio sends the existing Command-V event sequence exactly once.
- If permission is unavailable, Clipio keeps the selected content on the pasteboard, does not send Command-V, and gives the user a concise explanation.
- The permission explanation must not appear during launch, background capture, ordinary Copy, or shelf opening.
- The shelf's animation and close behavior remain unchanged.

### Smallest safe design

Change the Accessibility helper from a no-op into a small decision boundary that returns whether the app is trusted. The paste path must stop before creating keyboard events when trust is absent. When the user explicitly requests Paste, use the standard macOS trust prompt for the not-determined case and provide a route to the correct System Settings page for denied or revoked access.

The decision logic must be testable without changing real system permissions. This can be achieved by injecting the trust result or isolating the system query behind a closure/protocol local to the permission helper. It must not introduce a general dependency-injection framework.

### Error handling

If the system trust query or settings-opening action fails, Clipio remains in copy-only mode and presents a short non-sensitive explanation. It must never claim that Paste succeeded when no key event was sent.

### Verification boundary

Unit tests cover granted and unavailable decisions, including the guarantee that no key events are generated when unavailable. Manual testing covers not determined, denied, granted, revoked, and re-granted macOS permission states and confirms focus returns to the intended destination application.

## Design 3: Isolated UI-test runtime

### Required behavior

- UI tests launch the status item, shelf, shortcuts, search, and card interface.
- UI tests never load the owner's SwiftData database.
- UI tests never read from or write to the real general pasteboard.
- UI tests never post real keyboard events, request permissions, send notifications, or launch other applications.
- Test history is deterministic and contains synthetic text only unless a particular test supplies another synthetic fixture.
- Unit-test behavior remains unchanged.
- Normal application startup remains unchanged.

### Smallest safe design

Separate the current single `enable-testing` meaning into explicit runtime capabilities:

- unit-test mode: retain the existing in-memory/testing behavior;
- UI-test mode: initialize the full application interface while substituting isolated storage and safe clipboard/paste behavior.

The UI test target will pass a dedicated launch argument. App startup will still construct the panel and status item in UI-test mode. Synthetic fixture loading will be small and deterministic. Safety checks must make it impossible for UI tests to fall back silently to the real pasteboard or persistent store.

This work should extend the existing runtime-environment pattern rather than introducing a broad new application architecture.

### Error handling

If isolated storage or test fixtures cannot be initialized, the UI test must fail immediately with a clear test-only error. It must never fall back to production storage.

### Verification boundary

UI automation will verify status-item creation, open/close, search/clear, arrow navigation, selection, copy interception, Paste interception, pin/unpin, and deletion. A post-test assertion or test-only guard will verify that no synthetic marker reached the real pasteboard or persistent database.

The existing pop-out and close animations are part of the test surface: tests may wait for their completion but must not disable, shorten, or replace them in production code.

## Design 4: External-beta release pipeline

### Required behavior

The external-beta artifact must:

- use the Release configuration;
- enable Hardened Runtime;
- exclude `com.apple.security.get-task-allow`;
- be signed with a valid Developer ID Application identity;
- preserve required sandbox and Sparkle helper entitlements only where justified;
- be notarized and stapled;
- pass `codesign` verification and Gatekeeper assessment;
- declare and produce the intended supported architectures;
- contain the correct Clipio identifier and version;
- be tested as the final packaged download, not only from DerivedData.

### Smallest safe design

Keep `scripts/release-local.sh` as the local developer workflow. Add a separate beta-release script or CI workflow that archives, exports, packages, notarizes, staples, and validates the external artifact. Do not silently turn the local installer into a distribution tool.

Signing certificates, Apple credentials, and notarization credentials must be provided through Keychain or protected CI secrets. No credential, password, token, private key, or machine-specific secret may enter the repository.

The current uncommitted project-file change swaps Hardened Runtime values between Debug and Release. The release task must inspect and resolve that exact change with the owner before editing or staging the project file.

### Error handling

The pipeline stops on build, signing, packaging, notarization, stapling, or validation failure. It must never label or publish a partially validated artifact as a beta. Failure output must identify the failed stage without exposing credentials.

### Verification boundary

Automated checks inspect the final artifact's signature, Team ID, Hardened Runtime, entitlements, architecture, identifier, and version; validate notarization/stapling; and require Gatekeeper acceptance. Manual testing uses a clean Mac or disposable macOS account to download, open, grant permission, copy, paste, quit/reopen, and test launch at login.

This task has an external prerequisite: an active Apple Developer membership, a Developer ID Application certificate, and configured notarization credentials.

## Design 5: Honest update experience for the first beta

### Required behavior

- The first external beta must not show functional-looking update controls when no Clipio update feed exists.
- The application must not contact the stale Maccy appcast.
- The first beta will be updated manually using a later signed and notarized beta artifact.
- Hiding the unfinished updater must not affect normal launch or shelf behavior.

### Smallest safe design

Disable updater initialization and hide Check for Updates / automatic-update controls for the beta configuration. Do not build a new Sparkle feed as part of this remediation. Keep Sparkle-related code only where removing it would cause wider, unnecessary change.

The stale repository `appcast.xml` must not be connected to Clipio. Its cleanup can be handled separately if it is not packaged or used.

### Error handling

There is no update error UI in this beta because no update request is started. Future updater work requires its own design covering signed appcasts, failure recovery, rollback, and data compatibility.

### Verification boundary

Tests verify updater initialization is disabled in the beta configuration and update controls are absent. The built Info.plist is inspected for stale feed configuration. A manual network observation on a disposable account confirms that launch and normal clipboard use do not trigger a Sparkle feed request.

## Task and commit boundaries

The implementation plan will preserve these checkpoints:

1. **Privacy checkpoint:** logging and copy feedback only.
2. **Permission checkpoint:** Accessibility decision and Paste behavior only.
3. **UI-test checkpoint:** isolated runtime and critical shelf tests only.
4. **Release checkpoint:** signing/notarization pipeline and configuration only.
5. **Update checkpoint:** updater initialization and controls only.
6. **Beta-candidate checkpoint:** final automated and manual verification evidence; no feature additions.

No checkpoint may include unrelated formatting, visual redesign, dependency upgrades, storage migrations, performance refactors, or post-beta features.

## Final acceptance criteria

Clipio is eligible for external beta only when all of the following are true:

- Synthetic clipboard markers are absent from logs and Notification Center.
- Copy sounds work without notification permission.
- Paste behaves correctly for granted, denied, revoked, and not-yet-determined Accessibility states.
- Critical UI tests run against the actual shelf using isolated synthetic state.
- The shelf's existing pop-out and close animations remain visually and behaviorally unchanged.
- All unit and required UI tests pass.
- The required Debug compile-check reports `BUILD SUCCEEDED`.
- The packaged Release artifact is Developer ID signed, Hardened Runtime enabled, notarized, stapled, and accepted by Gatekeeper.
- A clean-account manual checklist passes without using private clipboard data.
- Update controls are absent and no stale update request is made.

## Explicitly deferred work

The following ideas are valuable but belong to separate post-beta product discovery and specifications:

- Dropzone-style workflows
- music or currently-playing display
- media controls
- additional shelf utilities
- cloud or cross-device features beyond existing system clipboard behavior
- visual redesign or animation changes

These ideas must be evaluated against Clipio's core promise: a fast, private, lightweight clipboard manager. They are not prerequisites for the first external beta.
