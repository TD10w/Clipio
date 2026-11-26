# Clipio 2.9.2 release evidence

Published 2026-11-26 at https://github.com/TD10w/Clipio/releases/tag/v2.9.2 (normal release, marked Latest).

## Source

- [PR #23](https://github.com/TD10w/Clipio/pull/23) merged as `046da3c`; tag `v2.9.2` points to it. App 2.9.2, build 74, bundle `com.clipio.app`.
- The owner authorized merge and publication ("直接合并更新").
- Owner check on an installed Developer ID build of the fix: the Drop Zone appears when dragging from a Dock stack, the file lands in Collection, and Finder drags still work.
- Unit suite: 200 tests, 6 failed assertions in 5 `CollectionTests` (Trash/recycle and an iCloud Drive path comparing `/private/var` with `/var`). The same 5 tests fail on the `v2.9.1` tag on this Mac today, and they passed at the 2.9.1 release, so this is an environment change (likely the macOS update), not this fix. Still open.
- UI tests not run (automation mode cannot start here).

## Distribution

- App and DMG notarized (profile `Clipio-Notary-Production`), stapled, and accepted by Gatekeeper as Notarized Developer ID.
- DMG SHA256 `eea8397091b2dec81335fbc2fe40ee26a7a18cd8e5a3ceb80769ab0130ddda1c`.
- ZIP SHA256 `0acf16db0e840230086c03e6624e31d17162d26de03dd8d7dc31f47b0d808a2e`.
- Both assets were downloaded anonymously from the release and matched.

## Update channel

- `Clipio-74.zip` (10470844 bytes, identical to the release ZIP) and its checksum were uploaded to `clipio-updates`. The public bytes matched and passed Ed25519 verification against the embedded key before the appcast was replaced.
- The public appcast lists build 74 / 2.9.2, minimumSystemVersion 14.0, and matches the staged feed. GitHub served the old feed for about two minutes after the upload. The build-73 feed is kept at `build/Release-2.9.2-74/previous-appcast.xml`.
- Still open: an in-app 2.9.1 → 2.9.2 update on the owner's Mac.
