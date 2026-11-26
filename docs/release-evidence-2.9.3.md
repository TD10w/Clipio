# Clipio 2.9.3 release evidence

Published 2026-11-26 at https://github.com/TD10w/Clipio/releases/tag/v2.9.3 (normal release, marked Latest).

## Source

- [PR #25](https://github.com/TD10w/Clipio/pull/25) merged as `4a9ea44`; tag `v2.9.3` points to it. App 2.9.3, build 75, bundle `com.clipio.app`.
- The owner authorized merge and publication ("合并并发布").
- Owner check on a Developer ID preview build of the fix: dropping a Collection item onto the Xiaohongshu web upload area removes its card.
- The system log before the fix showed browsers ending the drag with operation 16 (move) while leaving the original in place.
- `CollectionTests`: the same 5 pre-existing failures (Trash/recycle, `/private/var` vs `/var`) before and after the fix; the new test passes. UI tests not run (automation mode cannot start here).

## Distribution

- The first build attempt failed at codesign ("A timestamp was expected but was not found"); the retry succeeded unchanged.
- App and DMG notarized (profile `Clipio-Notary-Production`), stapled, and accepted by Gatekeeper as Notarized Developer ID.
- DMG SHA256 `a0b334d628e2f0bee9a7ee4956956e47dcd162177cbfd33919bb79fd028c23b9`.
- ZIP SHA256 `b0a29e9b4499d3fb9308b40a5c55a1d82f2e876b001572b9f326508b4379f7ad`.

## Update channel

- `Clipio-75.zip` (10475406 bytes, identical to the release ZIP) and its checksum were uploaded to `clipio-updates`. The public bytes matched and passed Ed25519 verification against the embedded key before the appcast was replaced.
- The public appcast lists build 75 / 2.9.3 and matches the staged feed. GitHub served the old feed for about two minutes after the upload. The build-74 feed is kept at `build/Release-2.9.3-75/previous-appcast.xml`.
- Still open: an in-app 2.9.2 → 2.9.3 update on the owner's Mac.
