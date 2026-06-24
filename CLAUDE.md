# Clipio

A fork of [Maccy](https://github.com/p0deje/Maccy) — a lightweight macOS clipboard manager.
Licensed under MIT. This fork is a personal customization project.

## Project Goal

Rebuild the UI/UX while keeping Maccy's lightweight, fast core. Inspired by Supaste's card-based design.

## Development Workflow (always follow)

The owner has no coding background. Their job is product judgment ("does this look/feel right");
the assistant's job is everything technical. Optimize for **fewest manual build-and-look cycles**.

1. **Compile-check before every handoff.** After editing, run:
   `xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO`
   Only hand off to the owner once it reports `BUILD SUCCEEDED`. Never make them discover a
   syntax/type error with their own `Cmd+R`.
2. **Decide before building.** For anything non-trivial, agree on what we're building (sketch/mockup
   or a short spec) before writing code. Avoid changing direction mid-implementation.
3. **Batch related changes.** Group several related edits into one build, instead of one-change-one-build.
4. **Commit working checkpoints.** After each stable, verified state, `git commit` so experiments can
   be reverted with one command. Tell the owner the short hash.
5. **Ask for specific feedback.** Encourage "the image is too small" / "it didn't switch" over "it's wrong."
6. The Xcode scheme is still named **`Maccy`**; the app/target/display name is **Clipio**.
   New `.swift` files must be registered in `Clipio.xcodeproj/project.pbxproj` (manual groups,
   not auto-synced) — the assistant can edit the pbxproj directly instead of asking the owner to add files.

## App Identity

- **Name**: Clipio
- **Based on**: Maccy (fork of `p0deje/Maccy`, forked at `TD10w/Maccy`)
- **Bundle ID**: `com.clipio.app`

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

| Feature | Status |
|---|---|
| Horizontal card layout (`CardItemView`, `HistoryListView`) | ✅ Done |
| Wide+short shelf, drops from top-center of screen | ✅ Done |
| Per-card shortcut number badge + pin indicator | ✅ Done |
| Color value → color swatch card | ✅ Done |
| Settings + quit icons in header | ✅ Done |
| Drag card out to paste (text + image as PNG) | ✅ Done (image drag occasionally flaky) |
| Hover preview popup (`PreviewPopupPanel`, below shelf) | ✅ Done; tuning size/layout |
| Rename to Clipio + new app icon | ✅ Done |
| Drag to reorder | ❌ Dropped (kept lightweight) |
| Integrated slideout preview (original Maccy) | ❌ Removed; replaced by popup |

## Key Files (the live card-shelf tree)

The panel content is `ContentView → HeaderView → HistoryListView → CardItemView`,
plus a separate hover preview window. The old Maccy vertical-list views have been
deleted (commit removing the dead UI island), so don't go looking for `ListItemView`,
`HistoryItemView`, `SlideoutView`, etc. — they're gone.

- `Maccy/Views/CardItemView.swift` — the individual clipboard card (image / text / color)
- `Maccy/Views/HistoryListView.swift` — the horizontal card shelf (LazyHStack in a ScrollView)
- `Maccy/Views/HeaderView.swift` — search field + clear/settings/quit controls
- `Maccy/Views/FloatingGlassStyle.swift` — shared sizes, radii, tints for the shelf/cards
- `Maccy/PreviewPopupPanel.swift` / `Maccy/Views/PreviewItemView.swift` — hover preview below the shelf
- `Maccy/FloatingPanel.swift` — the shelf window (size/position; drops from top-center)
- `Clipio.xcodeproj` — app target, bundle ID, and icon configuration
- New `.swift` files must be registered manually in `Clipio.xcodeproj/project.pbxproj`

The old slideout-preview controller (`SlideoutController`) and the window-resize
machinery it drove have been removed; the shelf is fixed-size (no `.resizable`),
and the only preview is the hover popup (`PreviewPopupPanel`). The dormant
multi-select infra in `NavigationManager` (the `extend*` selection methods) is the
last known leftover, kept for a future pass.

## What We Decided NOT to Do

- Website screenshot preview (requires network fetch per URL, kills lightweight feel)
- Category/tag system (needs database schema changes, too complex)
- Cloud sync (defeats the privacy-first design)
