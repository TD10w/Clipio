# Clipio public beta readiness

Assessment date: 2026-09-05. Intended audience: a small group of testers using GitHub distribution. This is not a Mac App Store submission assessment.

## Current result

The first early public beta is published as [`v2.6.1-beta.1`](https://github.com/TD10w/Clipio/releases/tag/v2.6.1-beta.1). It is suitable for collecting tester feedback, with independent installation on another Mac and the full UI checklist explicitly outstanding. The owner authorized publishing it with those limitations disclosed.

The universal app has been Developer ID signed, accepted by Apple notarization, stapled, and validated again after extraction from the final ZIP. The README and release notes distinguish these completed distribution checks from unperformed installation/UI testing.

## Release gate

- [x] Prepare candidate `2.6.1-beta.1` with app version `2.6.1`, build `60`, and bilingual release notes. The GitHub tag points to `3396981`.
- [x] Make a Developer ID Application identity and notarytool profile available on the release machine. Keep credentials in Keychain, never in repository files.
- [x] Build, sign, notarize, and staple the candidate. This run used a clean staging directory to avoid Finder metadata in the reused build output; the script's `--validate-only` gate passed. Direct Xcode Release settings do not provide the full distribution workflow.
- [x] Verify the app contains both `arm64` and `x86_64` binaries, passes signature verification, stapling validation, and Gatekeeper assessment (also after extracting the final ZIP).
- [ ] Download and launch the actual ZIP on another Mac; verify permissions and core workflows below. Record the tested OS and CPU, and avoid claiming compatibility beyond evidence.
- [ ] Review media/privacy/licensing items in `media-notes.md`.
- [x] Publish the verified ZIP and checksum with bilingual release notes, installation steps, known issues, and source tag `v2.6.1-beta.1` (`3396981`).
- [x] Update both READMEs with direct downloads, install steps without Xcode, and dark screenshots.

The release script reads `CLIPIO_DEVELOPER_ID` and `CLIPIO_NOTARY_PROFILE`, builds a universal app, signs nested Sparkle code, submits for notarization, staples, and assesses the artifact. Environment variable values are release-machine configuration. Do not copy personal identifiers into public documentation.

Apple documents this distribution path in [Developer ID support](https://developer.apple.com/support/developer-id/) and [notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Tester installation instructions once a ZIP exists

Download the Clipio ZIP from this repository's Releases, extract it, move Clipio.app to Applications, and open it. The app runs in the menu bar. Grant Accessibility only for automatic paste. Check macOS requirements before downloading. Do not tell users to disable Gatekeeper globally. Updates will be manual until Clipio has its own updater configuration.

## Smoke test record to complete on the release artifact

- [ ] Open/close from shortcut and menu bar; search and select cards.
- [ ] Copy text, image, and file references; paste to at least two destination apps.
- [ ] Test copying without Accessibility, then automatic paste after granting it.
- [ ] Pin/unpin; verify pinned items survive ordinary capacity eviction.
- [ ] Copy more than 200 distinct entries with default capacity while scrolled away from the newest card; verify newest item visibility and selection.
- [ ] Confirm clear-history cancellation/confirmation and separate system-clipboard clearing behavior.
- [ ] Relaunch and confirm history persists; test ignored-app capture behavior.
- [ ] Check light/dark appearance and multi-display positioning.

## Repository and privacy findings

- No obvious tracked credential/key/provisioning/database file was found by the filename and targeted text scan. This is not an exhaustive secret scan of all historical Git objects or binary media.
- Personal filesystem paths and account details in current documentation were sanitized. Names/addresses in Git commit authorship and older revisions remain; editing current files does not erase history. Do not rewrite public history merely to remove non-secret metadata without a separate decision.
- The current issue form no longer requests full settings dumps; the inherited sponsor button was removed.
- The unpublished preparation commits were consolidated for publication so previously removed personal account details are not introduced through their intermediate history. A local backup preserves the original checkpoints. Existing public history is unchanged.
- Keep upstream MIT copyright, code attribution, dependency licenses, and meaningful source links. Internal `Maccy` scheme/source/storage names are not branding defects and changing storage names may require migration.
- Legacy localized Maccy strings and unused Sparkle code remain for a separate cleanup. The stale upstream appcast has been removed from the repository and is no longer packaged. No `SoftwareUpdater()` construction was found in app source. Do not advertise automatic updates.
- App About source link corrected to Clipio; inherited contributor credits remain.
- Existing handoff reports a flaky UI lifecycle test and database failure-recovery risks. Do not describe them as newly reproduced defects or claim that previous test counts were rerun here.

## Follow-up after a small beta

Collect concrete reproduction steps through Clipio Issues. Prioritize crash/data-loss reports, paste failures, and capacity behavior before adding features. App Store submission, a website, and an elaborate promotional film are not prerequisites for inviting a small GitHub beta group.

## Verification performed in this review

- Required unsigned Debug `xcodebuild` with scheme `Maccy`: **BUILD SUCCEEDED**.
- `tests/beta-surface-tests.sh`: passed.
- `tests/release-beta-tests.sh`: passed (script regression tests, not Apple notarization).
- Relative links in both READMEs and the two new checklist/media documents: passed.
- `git diff --check`: passed.
- Core unit suite rerun in a clean temporary build directory: 85 tests passed, 0 failures (TEST SUCCEEDED). UI suite and second-Mac installation remain pending. The current candidate has passed Apple notarization and local distribution validation.

## Current local candidate

- App source: release tag `v2.6.1-beta.1` (same app source as the local artifact build); app version `2.6.1`, build `60`.
- Artifact: `build/Beta/Clipio-2.6.1-beta.1.zip` (ignored by Git).
- SHA-256: `81e99c3d8bc7b35df881b7c87e3536ca501a05aed385c51a7749dd387fb79e87`.
- Both `arm64` and `x86_64` confirmed with `lipo`; Developer ID signing includes nested Sparkle helpers and secure timestamps. Deep strict signature verification passed.
- Release compile: BUILD SUCCEEDED. Generated Finder metadata in the reused build directory prevented direct signing; the final app was staged without resource metadata and signed in a clean temporary directory.
- Apple notarization: **Accepted** on 2026-09-05. Stapling validation and Gatekeeper assessment passed (`source=Notarized Developer ID`), including a fresh extraction of the final ZIP.
- Final ZIP size: 7,322,997 bytes. SHA-256 sidecar: `build/Beta/Clipio-2.6.1-beta.1.zip.sha256`. The old pending-notarization ZIP is not the final distribution artifact.

The owner selected dark, transparent screenshots for public presentation. Both README images now use native macOS window PNG captures of the dark appearance with alpha preserved, replacing the earlier light captures. Sample content was visually reviewed.

### UI smoke attempt

The four selected UI tests (search, Enter-copy, image copy, pin) did not execute:
XCTest reported `Timed out while enabling automation mode.` The run was stopped
and is not counted as a pass. This is a test-environment startup limitation, not
evidence that these app workflows failed. Repeat on an unlocked macOS session
with UI automation available, then perform the release-artifact manual checklist.

## Public visitor checks

- GitHub Release is public and marked Pre-release; ZIP and checksum assets are uploaded.
- GitHub-provided asset SHA-256 digests match the local files. An unauthenticated download from the public ZIP URL also matched the final artifact SHA-256.
- English README rendering was checked in the browser: language switch, direct download, dark screenshots, installation steps, and limitations are visible.
- Issues were enabled and the template chooser displays Bug Report and Feature request.
- Repository homepage now links to Clipio Releases instead of the upstream Maccy website.
- Existing public Git history was not rewritten; only unpublished preparation commits were consolidated.
