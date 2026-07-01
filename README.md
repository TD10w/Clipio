# Clipio

Clipio is a lightweight, card-based clipboard manager for macOS. It keeps Maccy's fast, private clipboard engine while rebuilding the experience around a visual card shelf.

## Why Clipio

- Visual card-based clipboard history
- Keyboard-first search and navigation
- Pinned items with quick shortcuts
- Native macOS experience
- Local and private by default

## Status

Clipio is under active development. A packaged public release is not available yet; build the app locally to try the current version.

## Requirements

- macOS Sonoma 14 or later
- Xcode with Swift support

## Build locally

1. Clone this repository.
2. Open `Clipio.xcodeproj` in Xcode.
3. Select the available macOS app scheme and run the app.
4. Grant Accessibility permission when prompted if you want Clipio to paste automatically.

## Basic workflow

- Press `Shift + Command + C` to open Clipio.
- Type to search clipboard history.
- Press `Return` to copy the selected item.
- Use `Option + Return` to paste it into the active app.
- Pin frequently used items to keep them at the top.

## Privacy

Clipboard history stays on your Mac. Clipio also respects common transient and concealed pasteboard types used by password managers and other privacy-sensitive apps.

## Credits

Clipio is a personal product exploration built on top of [Maccy](https://github.com/p0deje/Maccy). Maccy provides the reliable clipboard foundation; Clipio explores a different interaction and visual model.

## License

[MIT](./LICENSE)
