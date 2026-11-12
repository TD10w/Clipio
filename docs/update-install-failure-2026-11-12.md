# Real update installation failure and repair

The owner's first 2.8.0 (68) → 2.8.1 (69) in-app upgrade failed with “An error occurred while running the updater.” This is a failed acceptance result, even though the released packages, update signatures and public feed passed distribution checks.

Local logs show that the download completed but Autoupdate could not create `~/Library/Caches/com.clipio.app/org.sparkle-project.Sparkle/Installation`: Cocoa error 513, underlying EPERM. The installed host has the required installer XPC setting and expanded `com.clipio.app-spks` / `com.clipio.app-spki` communication entitlements. The host remained on build 68.

Sparkle's [upstream fix #2882](https://github.com/sparkle-project/Sparkle/pull/2882) addresses installation cache paths for bundle identifiers ending in `.app`. Its [2.9.3 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.3) contains that fix. Clipio had resolved 2.6.4. The repair pins the official 2.9.3 package and changes no other dependency or app identity.

`tests/sparkle-cache-tests.sh` compiles and executes the resolved upstream cache-path implementation. It fails with 2.6.4 because Clipio's cache root looks like an app bundle, and passes with 2.9.3 while preserving the ordinary reverse-DNS layout. It does not launch the app or mutate user caches. Logs: `/tmp/clipio-sparkle-cache-red.log`, `/tmp/clipio-sparkle-cache-green.log`, `/tmp/clipio-update-installer-failure.log`.

The original 2.8.0 and 2.8.1 published packages are immutable. Repairing a failing installed updater requires one manual replacement. For the owner's requested end-to-end test, a clearly recorded local repair baseline will contain the fixed updater and a lower build number, so it can receive the real signed 2.8.2 (70) update. That baseline is not the original published 2.8.0 package and cannot establish that the original broken updater upgraded successfully. Actual Sparkle installation, relaunch and data continuity remain pending until observed or confirmed by the owner.

After dependency replacement the first test build encountered an obsolete precompiled Sparkle header module; a build-artifact clean resolved it. The clean run passed all 189 unit tests (`/tmp/clipio-282-tests-clean.log`). Update configuration, seven release-preparation tests and real Ed25519 checks also passed. Other resolved dependencies were unchanged.
