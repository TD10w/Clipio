# Clipio 2.7.5-beta.1 release evidence

Published 2026-11-11 at https://github.com/TD10w/Clipio/releases/tag/v2.7.5-beta.1.

## Icon correction

The user asked for the banana-horse application icon to occupy more of its visible enclosure. [PR #13](https://github.com/TD10w/Clipio/pull/13) enlarged the artwork and replaced the opaque exterior padding with transparency. Installation revealed that macOS still placed the legacy representation inside an additional gray enclosure. The PNG-only 2.7.4 release was therefore insufficient for the requested system appearance.

[PR #14](https://github.com/TD10w/Clipio/pull/14) adds `Clipio/AppIcon.icon` and registers it as `folder.iconcomposer.icon` in the resource phase. Its single artwork layer uses the enlarged PNG, with the system applying the enclosing icon shape. The source is compatible with Apple's documented Icon Composer workflow, which also generates legacy representations for earlier deployment targets. See [Apple's Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).

The native icon was checked through system rendering and then in Finder's actual Get Info window for the installed app. Finder displayed version 2.7.5 and the full gold icon enclosure. The intermediate 2.7.4 release now links to this corrected release.

## Build and distribution

- Tag source commit `dcb465709803a8b7b99fd5c5a29093eb16cad067`, app version 2.7.5, build 67, bundle `com.clipio.app`.
- Required Debug build passed. The built catalog contains default, dark and tinted `IconImageStack` appearances, plus the generated legacy ICNS. The user-approved enlarged artwork is included in the native document.
- Universal Release includes arm64 and x86_64 code, the native icon stack and 31 localization tables.
- Developer ID signing, Hardened Runtime, all-architecture deep strict signature verification, notarization, stapling and Gatekeeper checks passed.
- App notary submission `7d0f4397-0863-498b-b21c-29c911dbdf20`. DMG notary submission `931bc2a3-ddd5-49c9-92d4-b640f52518b8`.
- The final ZIP was extracted and validated. The DMG was mounted read-only and its executable, Info.plist, AppIcon.icns, Assets.car and signed resource manifest matched the ZIP. Its Applications shortcut pointed to `/Applications`, and the validation mount was detached.
- All four public download assets matched both their local SHA-256 values and GitHub's asset digests.

Final SHA-256 values

- DMG `8b7200b17193701080313731657d8140375c0b2ee2b7e558eaebb509d0b355e5`
- ZIP `7511a89545ecfa9367001743ad49461ff16d291b17af99d7d966af2852010b5f`

Build/validation logs are under `/tmp/clipio-2.7.5-*.log`. The earlier icon-export Debug check is `/tmp/clipio-2.7.4-icon-debug.log`. These checks focus on assets and packaging. Behavioral regression results for the preceding product changes remain in the [2.7.3 evidence](release-evidence-2.7.3-beta.1.md).

## Daily installation

The verified public ZIP was used to install `/Applications/Clipio.app`. The daily copy reports 2.7.5 (67), starts successfully, and its icon was visually checked in Finder. The previous app was backed up under ignored `build/Backups/before-2.7.5-20261111-121506/Clipio.app`.

Another-Mac installation, the full supported OS range and the user's visual acceptance remain separate from this machine's validation.
