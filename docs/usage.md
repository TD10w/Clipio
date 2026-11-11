# Usage and troubleshooting

[Back to Clipio](../README.md) · [简体中文](usage.zh-CN.md)

## Installation and updates

Use the DMG linked in the README. GitHub's “Source code” archives are for development, not installation. No Xcode or terminal commands are needed to use the download. The release also provides a ZIP; checksums are listed in its release notes.

Clipio runs in the menu bar rather than a normal Dock window. Updates are manual. If macOS refuses to open a download, confirm you have macOS 14 or later, download it again from this repository, and report the exact error. Do not disable Gatekeeper globally.

If you are upgrading from 2.6.1, the clipboard shortcut is now **Shift + Command + V**. **Shift + Command + C** opens file collection. Clipboard history is retained, and both shortcuts can be changed in Settings.

## Clipboard

Copy content in another app, then open the shelf. Typing searches the current shelf. Hovering previews a card. By default, Return copies the selected clipboard item; paste it in your destination with Command + V. Enabling “paste by default” changes this behavior.

Settings control appearance, transparency, history size, ignored apps and search behavior. The Transparency slider is clearer to the left and more frosted to the right. Default history capacity is 200; pinned items are retained separately from ordinary history eviction.

The first-launch English guide can be reopened from the gear menu → Getting Started, or Settings → General.

## File collection

- Start dragging a file, folder or browser image. Drop it on the small glass Drop Zone at the top of the screen. Rest there about half a second to open the full collection.
- Ordinary items dragged into Finder move the original. Pin an item first to copy it instead and retain it in the collection.
- Files from one drop form a Stack. Click to expand; click ‹ to collapse. When collapsed, dragging and pinning apply to the group; when expanded, they apply to individual items.
- Items remain after quitting. Search matches file names; a hit inside a Stack shows that group.
- Local files are referenced, not duplicated. Browser images are stored in Clipio's own local data. Removing or clearing collection items does not delete the originals.

## Automatic paste permission

Option + Return needs **System Settings → Privacy & Security → Accessibility → Clipio**. Copying from a card and manually pasting with Command + V does not require this permission.

If automatic paste stops working after an update or replacement build, check Clipio's Accessibility entry again.

## Sensitive content

History is local, with no cloud sync or analytics. The database does not have app-level encryption. Clipio skips supported concealed/transient clipboard markers, but cannot identify every password copied as ordinary text. Configure ignored apps or pause capture as needed.

Clearing history and clearing the system clipboard are separate settings. Do not use clipboard history as the only copy of important content. When reporting bugs, do not upload clipboard databases, complete settings dumps, passwords, tokens or unredacted recordings.

## Beta limits

Second-Mac installation and the complete UI checklist still await independent verification. Cross-disk collection moves, behavior after a system restart, and multi-display dragging have not yet been verified. Some new interface text and the Accessibility prompt are English only. Dragging behavior can vary by destination app.

Technical follow-up and validation records are linked from the [development guide](development.md).
