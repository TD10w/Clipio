# Screenshot provenance

Captured on 2026-09-05 from the Debug build of the app source included in release tag `v2.6.1-beta.1`.

The app binary was copied to a temporary bundle with identifier
`com.clipio.screenshots` and launched in existing UI-test mode. This uses an
in-memory history and the named `com.clipio.ui-tests` pasteboard. Synthetic text
and a public GitHub URL were supplied; no real clipboard history was used.
The dark appearance was passed as a launch argument for this isolated copy.
Images were captured with macOS `screencapture -x -o -l WINDOW_ID`, preserving
the PNG alpha channel rather than flattening transparent regions into white.

- `clipio-shelf.png`: five sample cards, including text, URL, and a color swatch.
- `clipio-search.png`: actual search results for `ideas`.

Both images are window captures of the actual interface, not mockups. This is a
source-build demonstration, not evidence of a published or notarized release.
