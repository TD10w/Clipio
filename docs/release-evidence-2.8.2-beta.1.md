# Clipio 2.8.2-beta.1 update-installer repair

Release: https://github.com/TD10w/Clipio/releases/tag/v2.8.2-beta.1.

- [PR #16](https://github.com/TD10w/Clipio/pull/16) merged as `c41d0a80e366793c67954c36d7004630734b64ea`, the release-tag source. App 2.8.2, build 70; identity and data paths unchanged.
- The first real 68 → 69 upgrade failed before installation with an EPERM creating Sparkle's cache directory. Sparkle is now pinned to official 2.9.3, containing upstream [#2882](https://github.com/sparkle-project/Sparkle/pull/2882). Other dependencies remain unchanged.
- The real resolved cache-path regression failed on 2.6.4 and passed on 2.9.3. All 189 unit tests, update configuration, seven release-preparation tests, Ed25519 tests and required unsigned Debug build passed. A stale precompiled header after replacing the framework required a build-artifact clean before the successful test run.
- Universal arm64/x86_64 release, 31 languages, embedded Sparkle 2.9.3, production feed/key and all-architecture deep strict signatures verified in the extracted ZIP. App notarization: `ff489d62-0726-4458-9028-41304196cebd`. DMG notarization: `9b6a51b6-5c3d-4c13-a75b-59b151f6057d`. Stapling and Gatekeeper passed. Read-only mounted DMG matched ZIP executable, Info.plist, icon resources, collection sound and signed resource manifest; its Applications link and detach were verified.
- ZIP SHA256: `036a90f2202a6f13554990cab7fb569f3082f7647c0713774df7175ef1753bed`.
- DMG SHA256: `bb3dfae39e07771f9b912ca71fdd3334bf535df259cdd2696f913c7a36793a82`.
- Both regular packages and both checksum files were anonymously downloaded from the published prerelease and matched local hashes and GitHub asset digests. The public release tag was checked against the merge commit.
- Immutable `Clipio-70.zip` was publicly downloaded, hash-checked and verified against the production Ed25519 key before replacing the appcast. A request to the canonical feed URL using a Clipio/Sparkle user agent returned build 70, byte-identical to the staged feed and with a verified production signature. Published older ZIPs remain available.

Local artifacts: ignored `build/Release-2.8.2-beta.1-70/`. Logs: `/tmp/clipio-sparkle-cache-{red,green}.log`, `/tmp/clipio-282-tests-clean.log`, `/tmp/clipio-282-debug.log`, `/tmp/clipio-282-distribution.log`, `/tmp/clipio-282-dmg.log`.

## Recovery and remaining acceptance

The original broken updater may fail before installing its repair, so affected users need one manual install of 2.8.2. The original 2.8.0/2.8.1 release descriptions now point to the repaired release; their assets were not changed.

For the owner to test the real install/relaunch flow, a local-only repair baseline was separately Developer ID signed, notarized (`ac3a892d-c43e-4f7f-bee3-a4b9161f95af`), stapled and Gatekeeper-validated. It contains the repaired engine and current runtime fixes, but presents build 69 to receive the real public 70 update. It is marked `ClipioUpdateRepairBaseline` and lives at `build/UpdateRepairBaseline-69-Sparkle293/Clipio.app`. It is not the original published 2.8.1 package and was not uploaded as a replacement asset.

That local baseline was installed and restarted at `/Applications/Clipio.app` (PID 64111 at verification); the previous official 2.8.0 is backed up at `build/Backups/before-sparkle293-repair-20261112-123936/Clipio.app`. Actual upgrade to 70, relaunch and history/Star/Pin/settings continuity remain for owner acceptance. Preparing a signed baseline and validating feed/package signatures do not establish successful Sparkle installation.
