# Clipio

[English](README.md) · [简体中文](README.zh-CN.md)

A native macOS app for clipboard history and file collection. Find what you copied, keep useful items nearby, and gather files before moving them elsewhere.

**[Download for macOS — 2.7.5-beta.1](https://github.com/TD10w/Clipio/releases/download/v2.7.5-beta.1/Clipio-2.7.5-beta.1.dmg)** · [Release notes](https://github.com/TD10w/Clipio/releases/tag/v2.7.5-beta.1)

macOS 14+ · Apple Silicon & Intel · Signed and notarized · Early public beta

## Clipboard

Browse copied text, images, links and colors in a horizontal card shelf. Type to search, hover to preview, and pin items you use often.

![Clipio clipboard history](docs/screenshots/clipio-shelf.png)

## File collection

Drag files, folders or images onto the Drop Zone at the top of your screen. Files dropped together form a **Stack**; click to expand it. Press **Tab** to switch between clipboard and collection.

![Clipio file collection](docs/screenshots/clipio-collection.png)

Dragging an ordinary collection item into Finder moves the original. **Pin** it first to copy it instead and keep it in the collection.

## Get started

1. Download and open the DMG, then drag **Clipio.app** into **Applications**.
2. Open Clipio. It runs in the **menu bar**.
3. Copy something, then press **Shift + Command + V** to open your clipboard history.
4. Select a card with **Return**, then paste into your destination app with **Command + V**.

For automatic paste with **Option + Return**, allow Clipio in **System Settings → Privacy & Security → Accessibility**. The first-launch guide is also available from the gear menu → **Getting Started**.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| Shift + Command + V | Open clipboard history |
| Shift + Command + C | Open file collection |
| Tab | Switch shelves |
| Return | Copy the selected clipboard item |
| Option + Return | Paste into the active app |
| Option + P | Pin or unpin |
| Escape | Close the shelf |

These are defaults; shortcuts and paste behavior can be changed in Settings.

## Privacy

Clipboard history stays on your Mac. There is no cloud sync or analytics, and no app-level history encryption. Use ignored apps or pause capture before copying sensitive content.

The collection references local files; browser images are saved in Clipio's local app data. Removing an item from the collection does not delete its original file. Keep separate copies of important material.

## Updates and feedback

Updates are manual: quit Clipio, download the new version, and replace the app in Applications.

This is an early beta. File dragging can vary by destination app; cross-disk moves and multi-display dragging have not yet been verified. Some interface text is English only.

[Report an issue](https://github.com/TD10w/Clipio/issues/new/choose) with your Clipio version, macOS version and steps to reproduce. Use sample content in screenshots.

[More usage and troubleshooting](docs/usage.md) · [Build from source](docs/development.md)

## Credits

Designed and developed by [TD10w](https://github.com/TD10w). Built on [Maccy](https://github.com/p0deje/Maccy) by Alex Rodionov and its contributors. Code is available under the [MIT license](LICENSE).
