# Clipio 2.7.3-beta.1 release evidence

Published 2026-11-11: https://github.com/TD10w/Clipio/releases/tag/v2.7.3-beta.1

## Source and scope

- Getting Started guide merged through [PR #11](https://github.com/TD10w/Clipio/pull/11).
- Collection menu-bar overlap fix merged through [PR #12](https://github.com/TD10w/Clipio/pull/12).
- Release tag targets `6e73e5cceb89d6d822124143a76b0e2341f249b6`. App version 2.7.3, build 65, bundle ID `com.clipio.app`.
- The user approved the three-page English guide, then required investigating a screenshot before publication and approved the native-menu-entry correction.
- Unpublished build 64 ZIP/DMG files were superseded and were not uploaded. Only artifacts under ignored `build/Beta/2.7.3-final/` were released.

## Verification

- Required Debug build succeeded; all 134 unit tests passed. The original idle-overlay regression failed on the previous code, then passed with the native status item. Tests exercise actual status-button routing and receiver geometry on notched/non-notched/offset screens.
- Six relevant UI cases passed in batches: collection clear preserving Pin, collection deletion separate from clipboard history, two shortcuts, icon/Tab switching, Tab geometry with the new native entry enabled, and onboarding. An initial shortcut startup failure and failed recheck were retained. The harness could mistake the nearly transparent prewarm panel for the open shelf; using the existing launch-open flag resolved the targeted test. No full UI-suite or single-pass six-case result is claimed.
- Logs: `/tmp/clipio-menu-entry-red.log`, `/tmp/clipio-menu-entry-ui.log`, `/tmp/clipio-menu-entry-shortcut-recheck.log`, `/tmp/clipio-menu-entry-shortcut-ready.log`, `/tmp/clipio-menu-entry-final.log`, `/tmp/clipio-menu-entry-final-debug.log`.
- Read-only independent review found no Critical/Important issues. The empty → nonempty → empty native-item visibility sequence is not separately automated.
- Universal Release app contains arm64 and x86_64 code. Final ZIP extraction confirmed version/build/bundle identity and all 31 built language tables with the approved guide.
- App Developer ID signing, Hardened Runtime, Apple notarization, stapling and Gatekeeper checks passed. App notary submission: `1fa5f3fb-02fa-4662-ad2e-10a47fd81046`.
- Signed DMG notarization, stapling and Gatekeeper checks passed. DMG notary submission: `46afad3c-5fce-421f-bba2-968a936dd3de`.
- Final DMG mounted read-only; its app passed all-architecture deep strict signature validation and distribution validation. Main executable, Info.plist and signed resource manifest matched the ZIP payload. The Applications shortcut pointed to `/Applications`. The volume was detached after validation.
- All four published assets were downloaded from their public URLs without authentication. Each download's SHA-256 and GitHub's asset digest matched the local final file.

## Downloads

- `Clipio-2.7.3-beta.1.dmg`: `2259246c19d2e60c3137e27f84aedc68c82a2e55a119a41bf5314d2ac591c6ec`
- `Clipio-2.7.3-beta.1.zip`: `29a0499db5ef17c5a6e8dbd4944f12705a553ebe8e486d8e3c564d089a252b25`
- SHA-256 sidecars for both files are uploaded. READMEs link to the new DMG and release notes.

## Acceptance boundaries

This is a public prerelease. The installed daily app was not replaced. Quit both the old daily app and any preview copy before manually installing the download, to avoid duplicate entries and shortcut conflicts. No real clipboard or collection data was used as a test fixture.

Independent installation on another Mac, cross-disk moves, a full system restart and the user's real-world acceptance of the corrected menu-bar/drag experience remain distinct from these automated and distribution checks. Updates remain manual.
