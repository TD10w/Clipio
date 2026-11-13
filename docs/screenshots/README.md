# Screenshot provenance

## README demo (2026-11-13)

The owner supplied `clipio-A-liquid-glass-30s.mp4` for the README. The supplied product demo shows clipboard cards, file collection, Stack expansion, shelf switching, Favorites and pasting, with explanatory overlays. It is a supplied presentation video, not a new independent acceptance recording.

`clipio-demo.gif` is a looping, silent derivative of the complete 30-second video, converted locally with FFmpeg to 640 × 360 at 5 fps and a 256-color palette. No scenes, captions or app content were added or removed. Audio is omitted by the GIF format. The supplied 1920 × 1080, 30 fps MP4 is preserved outside the repository; only the README derivative is committed. Sampled source frames were reviewed before conversion.


## Current README images (2026-11-11)

The owner supplied two real Mac desktop screenshots and explicitly authorized cleaning up the desktop/menu bar and publishing the finished images to GitHub.

- `clipio-shelf.png`: the real clipboard shelf showing text, a color swatch, the app icon, a public repository link and a partially visible image card.
- `clipio-collection.png`: the real file collection shelf showing one collected DMG file.

The built-in ImageGen tool removed unrelated desktop icons/file labels and reduced the right side of the menu bar to Wi-Fi, battery and the original date/time. The original wallpaper composition, window placement, layout, controls, card contents and filenames were used as the preservation reference. These are retouched presentation images, not untouched screen captures. The original owner uploads remain private and are not committed.

Visual review checked removal of desktop labels, readable header/search controls, clipboard contents and Command-number badges, and the collection card's filename. The older version number in that example DMG filename is file content, not the current Clipio download version. The download links in the README are unchanged.

Prompt scope: clean desktop clutter and menu-bar clutter only; preserve the real app interface and contents; do not add UI, files, labels, titles, or feature claims. Full input prompts are retained locally with the media pack rather than publishing the desktop filenames they remove.

The previous README shelf screenshot is retained in `archive/2026-09-05/`; the earlier search screenshot remains at `clipio-search.png` for historical reference.

---

# Earlier source-build captures (2026-09-05)

Captured on 2026-09-05 from the Debug build of the app source included in release tag `v2.6.1-beta.1`.

The app binary was copied to a temporary bundle with identifier
`com.clipio.screenshots` and launched in existing UI-test mode. This uses an
in-memory history and the named `com.clipio.ui-tests` pasteboard. Synthetic text
and a public GitHub URL were supplied; no real clipboard history was used.
The dark appearance was passed as a launch argument for this isolated copy.
Images were captured with macOS `screencapture -x -o -l WINDOW_ID`, preserving
the PNG alpha channel rather than flattening transparent regions into white.

- `archive/2026-09-05/clipio-shelf.png`: five sample cards, including text, URL, and a color swatch.
- `clipio-search.png`: actual search results for `ideas`.

Both images are window captures of the actual interface, not mockups. This is a
source-build demonstration, not evidence of a published or notarized release.
