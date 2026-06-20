# Clip Barns

A fork of [Maccy](https://github.com/p0deje/Maccy) — a lightweight macOS clipboard manager.
Licensed under MIT. This fork is a personal customization project.

## Project Goal

Rebuild the UI/UX while keeping Maccy's lightweight, fast core. Inspired by Supaste's card-based design.

## App Identity

- **Name**: Clip Barns
- **Based on**: Maccy (fork of `p0deje/Maccy`, forked at `TD10w/Maccy`)
- **Bundle ID**: change from `org.p0deje.Maccy` to something like `com.clipbarns.app` in Xcode

## UI Vision

Replace Maccy's vertical list with a **horizontal card shelf** that drops down from the menu bar:
- Wide, short window (shelf shape, ~120px tall)
- Cards scroll horizontally
- Each card shows: image thumbnail / text preview / color swatch depending on content type
- Card footer: source app icon + time ago
- Search bar stays at top

## What Already Works in Maccy (don't re-implement)

- Image preview on hover (slideout panel, right side)
- Source app icon display (settings toggle, already exists)
- Clipboard polling every 500ms (lightweight, near-zero CPU)
- SwiftData storage (~30-60 MB RAM normal usage)
- Fuzzy/regex/exact search

## What We're Adding

| Feature | Difficulty | Status |
|---|---|---|
| Horizontal card layout | Medium | Not started |
| Wide+short window shape | Easy | Not started |
| Color value → color swatch card | Medium | Not started |
| Drag to reorder | Medium | Not started |
| Rename to Clip Barns | Easy | Not started |
| New app icon | Easy | Not started |

## Key Files to Edit

- `Maccy/Views/HistoryListView.swift` — change from vertical List to horizontal ScrollView + cards
- `Maccy/FloatingPanel.swift` — adjust window size/shape
- `Maccy/Views/ListItemView.swift` — redesign individual item as a card
- `Maccy.xcodeproj` — rename target, change bundle ID, swap icon

## What We Decided NOT to Do

- Website screenshot preview (requires network fetch per URL, kills lightweight feel)
- Category/tag system (needs database schema changes, too complex)
- Cloud sync (defeats the privacy-first design)
