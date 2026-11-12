# Clipio 2.8.3-beta.1 release evidence

Published 2026-11-12 at https://github.com/TD10w/Clipio/releases/tag/v2.8.3-beta.1.

## Source and authorization

- [PR #17](https://github.com/TD10w/Clipio/pull/17) merged as `5d00d6a77fd8722c15f576f460bd3315132dfe4b`, the release-tag source. Runtime fixes were built at checkpoint `cad7d8c`; later changes before merge finalized documentation. App 2.8.3, build 71, bundle `com.clipio.app`.
- The owner authorized packaging and publication after reviewing the local candidate and audit results. The release remains a beta with real WeChat-source, shortcut-recording, menu-bar-on-another-Mac and cross-volume checks open. Publication authorization was recorded independently of manual test results.
- The complete unit suite executed 200 tests with 199 passed, one native-focus-dependent skip and zero failures. UI smoke could not initialize automation mode. Required Debug build passed again for this publication. Update configuration/cache/signature tests and packaging-entry checks passed. See [the readiness review](beta-readiness-review-2026-11-12.md).

## Exact candidate and distribution

- The existing signed local candidate was copied into a canonical `Clipio.app` bundle and notarized. Its executable SHA256 remained `d1a5c3712b240787035102d8b0703f1d6dc9645e600346514b269a78520754ac`, matching the installed candidate. The current notary profile became readable at the start of this publication. The earlier Keychain lookup failure's cause remains unknown.
- App notarization accepted: `e734de29-84c8-41b1-91ae-ba723b77d545`.
- DMG notarization accepted: `3fbc24ac-525a-450d-b242-2d131efc316c`.
- Stapling, Gatekeeper and all-architecture deep strict signatures passed for the signed App, extracted ZIP and mounted DMG. Both architectures were verified for the main executable, Sparkle framework, Autoupdate, Updater and both XPC services. The bundle contains all 31 locales.
- The DMG was mounted read-only. Its executable, Info.plist, icon resources, collection sound and signed resource manifest matched the ZIP. Its Applications link pointed to `/Applications`; the mount was detached.
- ZIP SHA256: `849603da3e782fd38c2f0ee0ae219470bf8d149a669c8535da8572c4a7953eb6`.
- DMG SHA256: `0f885a7d93842b299a6f38ff0735027ea6b2c97d5c5135c91007a442d84ca7cd`.
- Both packages and both checksum files were anonymously downloaded from the published prerelease, matched local hashes and GitHub asset digests, and the public tag was verified against the merge commit.

Artifacts are in ignored `build/Release-2.8.3-beta.1-71/`. The first update-asset preparation could not read the relative release-notes path; repeating preparation with the absolute path passed. Update preparation log: `/tmp/clipio-283-update-prepare.log`. DMG log: `/tmp/clipio-283-dmg.log`. Final Debug build: `/tmp/clipio-283-final-debug.log`.

## Update channel and installed copy

- Immutable `Clipio-71.zip` and its checksum were uploaded to `clipio-updates`. The public archive matched the local release and passed production Ed25519 verification before appcast replacement. The previous feed for build 70 was preserved locally and older immutable archives remain available.
- A subsequent request to the exact canonical appcast URL using a Clipio/Sparkle user agent returned build 71. Its bytes matched the staged feed, its immutable URL and length matched the public archive, and production Ed25519 verification passed again using the public feed signature.
- The user's installed 2.8.3 copy received its notarization ticket and passed Gatekeeper distribution validation. Its executable still matched the reviewed candidate, allowing the existing running app to continue.
- The update component remains Sparkle 2.9.3. The earlier successful repair-baseline → official 2.8.2 in-app installation/relaunch is recorded in the [2.8.2 evidence](release-evidence-2.8.2-beta.1.md). A new 70 → 71 App-internal install/relaunch and broader tester workflows remain open.
