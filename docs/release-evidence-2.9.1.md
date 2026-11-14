# Clipio 2.9.1 release evidence

Published 2026-11-14 at https://github.com/TD10w/Clipio/releases/tag/v2.9.1 (normal release, marked Latest).

## Source

- [PR #20](https://github.com/TD10w/Clipio/pull/20) merged as `d1738be`; tag `v2.9.1` points to it. App 2.9.1, build 73, bundle `com.clipio.app`.
- The owner authorized merge and publication ("发布").
- Unit suite: 200 tests, 0 failures. Debug build succeeded. UI tests not run (automation mode cannot start here).
- Preview check: dragging the guide's sample picture showed the Drop Zone, the picture landed in Collection, and the task ticked; the guide window stayed put.

## Distribution

- App and DMG notarized, stapled and accepted by Gatekeeper; deep strict signature check passed; universal (x86_64, arm64); 31 locales; the new guide strings are in the bundle.
- DMG SHA256 `24c7da5459d331ede444f8b56d0dbce8b026542275e4f303d2241d713a6e387c`.
- ZIP SHA256 `e39ea33de9cdc922c9bbc0126aa60595342c905a3fefed6610529f189a180f2d`.
- Both assets were downloaded anonymously from the release and matched.

## Update channel

- `Clipio-73.zip` (10463262 bytes) and its checksum were uploaded to `clipio-updates`. The public bytes matched the release ZIP and passed production Ed25519 verification before the appcast was replaced.
- The public appcast lists build 73 / 2.9.1, minimumSystemVersion 14.0, matches the staged feed, and its signature verifies against the public archive. GitHub served the old feed for about a minute after the upload. The build-72 feed is kept at `build/Release-2.9.1-73/previous-appcast.xml`.
- Still open: an in-app 2.9.0 → 2.9.1 update on the owner's Mac.
