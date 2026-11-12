# Clipio 2.8.1-beta.1 release evidence

Published 2026-11-12: https://github.com/TD10w/Clipio/releases/tag/v2.8.1-beta.1.

## Source and acceptance

- [PR #15](https://github.com/TD10w/Clipio/pull/15) merged as `35fa9d42ca9e20f4520493c0189a9a287661cf88`; release tag `v2.8.1-beta.1` points to that merge. App version 2.8.1, build 69, bundle `com.clipio.app`.
- The owner accepted the installed attachment-drag fix and automatic removal of accepted unpinned entries, then explicitly authorized packaging, upload and merge. Pinned, cancelled and rejected entries remain; attachment copies preserve referenced original files.
- Cleanup follows the destination's accepted-drop callback. It does not establish that a chat message was sent or an asynchronous upload completed.
- Both fixes were reproduced by failing regressions before implementation. All 189 unit tests passed. Required unsigned Debug build for the release version passed. Update configuration, seven release-preparation tests and real Ed25519 valid/wrong-key/tampered-archive checks passed.
- Menu-bar visibility and shortcut-recording feedback remain separate, unresolved reports.

## Distribution

- Universal arm64/x86_64 Release, 31 localization directories, Developer ID signing and Hardened Runtime verified. Expanded Sparkle service entitlements and the production feed/public key were checked in the actual bundle. Silent installation and system profiling remain disabled.
- App notarization accepted: `90fdcf8f-78d1-4a7d-b858-eef566ab48f6`.
- DMG notarization accepted: `f8d29ec8-5702-4157-a8ab-f8f5e05145d4`.
- Stapling, Gatekeeper and all-architecture deep strict signature checks passed. Extracted ZIP passed distribution validation. DMG was mounted read-only, its App executable, Info.plist, icon resources, collection sound and signed resource manifest matched the ZIP, its Applications link pointed to `/Applications`, and it was detached.
- ZIP SHA256: `97d73bac078fdd6db73bc92d36ebdf990292bc7da9dec596ab6bb2324bd50912`.
- DMG SHA256: `dfdfba0a978e7fba93298476b38000892635d17da439b810e56ab8b042dc4877`.
- Both packages and both checksum files were anonymously downloaded from the published prerelease and matched local hashes and GitHub asset digests.

Artifacts: ignored `build/Release-2.8.1-beta.1-69/`. Logs: `/tmp/clipio-281-debug.log`, `/tmp/clipio-281-distribution.log`, `/tmp/clipio-281-dmg.log`. Unit tests and the accepted local fix are detailed in [the attachment fix record](attachment-drag-fix-2026-11-12.md).

## In-app update and owner test

- Immutable `Clipio-69.zip` and its checksum were uploaded to the existing `clipio-updates` prerelease. Public download hash and production Ed25519 signature were verified before replacing `appcast.xml`. Build 68 remains available.
- Published feed content identifies build 69 and the immutable ZIP URL/length; its signature was independently checked against the public ZIP and production public key. A cache-bypassed public request returned the new feed while an initial canonical request still returned cached build 68; fixed-URL cache refresh is checked separately below.
- A subsequent request to the exact canonical feed URL using a Clipio/Sparkle user agent returned build 69. Its bytes matched the staged feed, and its Ed25519 signature verified against the independently downloaded public ZIP. The earlier stale redirect briefly returned 404 after replacement; the successful App-style check was made after that observation. Evidence files are under `build/Release-2.8.1-beta.1-69/public-verified/`.
- The user's accepted local build was ad-hoc signed with no configured update feed. For the requested real upgrade test, the published 2.8.0 (68) official ZIP was anonymously downloaded, hash/signature/notarization/feed/key verified, and installed at `/Applications/Clipio.app`. It starts successfully, with the accepted local fix backed up at ignored `build/Backups/before-68-to-69-update-test-20261112-122516/Clipio.app`.
- This baseline installation is preparation, not an App-internal upgrade. The owner still needs to choose Check Now, install/restart to 2.8.1 (69), and confirm history, Star/Pin, settings and attachment behavior. No successful Sparkle installation is claimed yet.

## Subsequent real acceptance result: failed

The owner attempted the in-app update and supplied an Update Error screenshot. The download succeeded but Autoupdate could not create its installation cache (EPERM), leaving build 68 installed. This is a failed upgrade acceptance result. Investigation and the official Sparkle 2.9.3 repair are recorded in [the installation failure record](update-install-failure-2026-11-12.md); 2.8.2 replaces the defective updater. The original 2.8.0/2.8.1 published assets were not overwritten.
