# Clipio 2.9.0 release evidence

Published 2026-11-14 at https://github.com/TD10w/Clipio/releases/tag/v2.9.0, the first non-beta release (marked Latest).

## Source

- [PR #19](https://github.com/TD10w/Clipio/pull/19) merged as `868d7b0`; tag `v2.9.0` points to it. App 2.9.0, build 72, bundle `com.clipio.app`.
- The owner authorized merge and publication ("合并，带着些改动 可以发布了").
- Unit suite: 200 tests, 0 failures. UI tests could not run (XCTest timed out enabling automation mode). Repo checks passed: beta-surface, make-dmg, release-beta, release-local, update-signature and the Python update tests.

## Distribution

- DMG and ZIP notarized, stapled, accepted by Gatekeeper; universal (Apple silicon and Intel); all 31 locales present.
- DMG SHA256 `7f74147d2772fe81c95b724c56232e142752366f0019f1f93e0204590544271e`.
- ZIP SHA256 `0b4d32378fd5aa75cd5a8de57ec1b323babb5484028738283d4f38d4c0444b81`.
- Both assets were downloaded anonymously from the release and matched the local hashes.

## Update channel

- Immutable `Clipio-72.zip` (10426840 bytes) and its checksum were uploaded to `clipio-updates`. The public bytes matched and passed production Ed25519 verification before the appcast was replaced.
- The public appcast now lists build 72 / 2.9.0, minimumSystemVersion 14.0, and matches the staged feed. The build-71 feed is kept at `build/Release-2.9.0-72/previous-appcast.xml`.

## In-app update

- On the owner's Mac, the installed 2.8.3 (71) checked for updates in Settings, installed 2.9.0 and relaunched. The owner reported it worked. Afterwards `/Applications/Clipio.app` reported 2.9.0 (72), and `spctl` accepted it as Notarized Developer ID.
- Still open: an install on a second Mac.
