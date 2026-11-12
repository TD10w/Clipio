# Development and maintenance

[Back to Clipio](../README.md)

## Build from source

Requires macOS 14 or later and full Xcode. Command Line Tools alone are insufficient. Choose an Xcode release compatible with your macOS; the first build resolves the pinned Swift packages.

```sh
git clone https://github.com/TD10w/Clipio.git
cd Clipio
open Clipio.xcodeproj
```

Select the **Clipio** scheme and **My Mac**. If signing is requested, choose your development team in Signing & Capabilities.

For an optimized local build without installing it:

```sh
./scripts/release-local.sh --build-only
open build/LocalRelease/Build/Products/Release/Clipio.app
```

A locally signed build is not the notarized package distributed in Releases.

## Validation and releases

- [Release checklist](public-beta-checklist.md): signing, packaging and distribution steps.
- [Project handoff](beta-readiness-handoff.md): source verification and outstanding acceptance work.
- [2.7.5 release evidence](release-evidence-2.7.5-beta.1.md): the current download's packaging and installation records.
- [Screenshot provenance](screenshots/README.md) and [media inventory](media-notes.md): image sources, retouching and legacy assets.

Database startup failure recovery and an intermittent automated window-lifecycle failure remain technical follow-up items. See the handoff for the evidence and acceptance boundaries; a successful build is not a complete product walkthrough.

The legacy animation source in `Designs/Clipio-Demo/` is a reconstructed product animation, not a current live recording. Legacy Maccy App Store assets are not demonstrations of Clipio. These development assets are not presented as a public demo in the README.

## Contributions and licenses

Follow the repository's `CLAUDE.md` for development workflow. Preserve the upstream MIT copyright and license notices and meaningful source references. Storage compatibility names need a migration before changing them.

The root [LICENSE](../LICENSE) covers code. Third-party media, fonts and audio have their own provenance and redistribution requirements; consult the media inventory before reusing them.
