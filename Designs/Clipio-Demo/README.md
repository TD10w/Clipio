# Clipio Demo Video

A 20-second, 1920×1080 Hyperframes product film for Clipio.

## What it shows

- A cleaner Apple-style product-material cover
- The `⇧⌘C` shortcut and top-center shelf unfold
- A real hover → `⌥P` → pinned-card interaction
- One complete Safari `⌘C` → Clipio capture → `Return` choose → Notes `⌘V` workflow
- The closing position: `Fast. Visual. Local.`

This second version is a faithful motion reconstruction built from Clipio's real visual
assets and current layout metrics. It intentionally avoids exposing live clipboard data.
A sanitized screen recording can replace the reconstructed interaction shots later without
changing the story or timing.

## Preview

```bash
npm run dev
```

Open the Studio URL printed by Hyperframes.

## Verify

```bash
npm run check
```

The composition currently passes runtime, layout, motion, and WCAG AA contrast checks.
Hyperframes reports one non-blocking maintainability warning because the coordinated
multi-scene transition timeline is kept in a single composition.

## Render

```bash
npm run render:draft
npm run render
```

Renders use one worker to remain reliable on memory-constrained machines. Generated MP4
files are kept in `renders/` and ignored by Git.
