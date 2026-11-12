# Clipio In-App Updates Implementation Plan

> Execute inline in this isolated worktree; user explicitly requested continuation without subagents or repeated confirmation.

**Goal:** Automatic checks and user-approved installation through Sparkle, with a signed release preparation path.
**Architecture:** A validated bundle configuration gates one updater owned for the app lifetime. Developer builds and tests never start it. Release tooling injects configuration before signing and prepares a verified appcast without uploading.
**Tech Stack:** SwiftUI, Sparkle 2, Python standard library, CryptoKit.
**Spec:** User-approved interaction in the 2026-11-12 conversation: automatic checks, Install/Later, release notes, manual check in settings; preserve existing user data.

## Global Constraints
- Isolated branch and DerivedData; never replace the running app or touch other worktrees.
- Never use the upstream Maccy feed; preserve com.clipio.app and storage paths.
- No silent installation. No public upload in this implementation session.
- Unconfigured builds expose no update controls or requests.

## Review Focus
- Missing or malformed configuration: stay disabled, reject release preparation.
- Debug and test launches: never initialize Sparkle.
- A signing key different from the embedded public key: reject preparation.
- Failed generation: leave no partial output; never overwrite existing artifacts.
- Actual installed old-to-new update and data retention remain a separate acceptance gate.

### Task 1: Configured app updater
**Files:** Clipio/UpdateConfiguration.swift, SoftwareUpdater.swift, AppDelegate.swift, Settings/GeneralSettingsPane.swift, Info.plist, project.pbxproj; tests/update-configuration-tests.swift.
**Interface:** UpdateConfiguration.isEnabled(info:isDebug:isTesting:) -> Bool; SoftwareUpdater.shared exposes isConfigured, canCheckForUpdates, automaticallyChecksForUpdates, start(), checkForUpdates().
- [x] Write and run failing configuration tests (HTTPS/key length, debug/test, missing configuration).
- [x] Implement gate, lifetime owner, KVO settings and startup; reuse existing localized update strings.
- [x] Run standalone Swift tests and isolated Debug build.

### Task 2: Release configuration and feed preparation
**Files:** scripts/update-release.py, scripts/verify-update.swift, scripts/release-beta.sh, tests/test_update_release.py, tests/beta-surface-tests.sh, docs/in-app-updates.md.
**Interface:** configure --plist modifies only unsigned/pre-resign plist from CLIPIO_UPDATE_FEED_URL and CLIPIO_UPDATE_PUBLIC_KEY; prepare --app --output --sparkle-bin validates distribution, creates archive and appcast, verifies Ed25519 against embedded public key, atomically produces output directory.
- [x] Write and run failing release tests (partial config, malformed URL/key, wrong signature, invalid/missing feed entry, output safety).
- [x] Implement scripts and integrate before signing / after notarization respectively.
- [x] Run synthetic generation with temporary signing key, all shell tests and unit suite; document real distribution acceptance still pending.
- [x] Review diff, verify built bundle settings/resources, commit checkpoint.

## Execution notes
- Plan review/execution method already authorized by user's continuation instruction; no new approval pause.
- No independent review agent: explicit user instruction forbids spawning agents. Perform a focused self-review.


## Verification record (2026-11-12)
- Isolated Debug build: BUILD SUCCEEDED, `/tmp/clipio-in-app-updates-build-final.log`.
- Release build and local signature validation: `zsh tests/release-local-tests.sh` passed (build-only, no install).
- Unit suite: 134/134 passed, `/tmp/clipio-in-app-updates-tests-final.log`.
- First unit run had `ClipboardTests.testIgnoreApplication` fail its inverted expectation; a targeted repeat and the full repeat passed. The test depends on the live foreground application. No unrelated clipboard code was changed.
- 6 Python release validation tests, standalone Swift configuration tests, real Ed25519 tests (valid/wrong-key/tampered archive), synthetic real Sparkle appcast generation and failure cleanup passed.
- Existing beta-surface, release-beta, release-local and make-dmg shell tests passed.
- Built app Info.plist confirmed no feed/key, automatic checking default true, silent installation disabled; built en/zh-Hans/zh-Hant GeneralSettings resources contain update labels.
- Self-review corrected real generator compatibility: Sparkle writes version as an item child element, not an enclosure attribute; used the installed tool's `--maximum-deltas 0` option.
- No production keys created, GitHub assets uploaded, branch merged, daily app replaced, or real installed old-to-new update accepted.
- Pending release gate: owner confirms dedicated GitHub update channel, production key provisioning, signed/notarized bootstrap package and separate-device update/data-retention walkthrough. This remains explicit in docs/in-app-updates.md.
