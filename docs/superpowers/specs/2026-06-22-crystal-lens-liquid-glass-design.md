# Clipio Crystal Lens Liquid Glass Design

**Status:** Approved for implementation

**Selected direction:** Option 1 — Crystal Lens

**Visual reference:** `output/clipio-crystal-lens/option-1-reference.png`

## Product intent

Make Clipio feel like a clear, dimensional piece of Apple-style Liquid Glass while preserving the current fast horizontal clipboard shelf. This is a visual-material refinement, not a layout redesign or feature expansion.

The result should feel lighter and more transparent than the current blue acrylic treatment. Desktop color must visibly travel through the tray and cards, with legibility provided by native vibrancy, restrained highlights, and local contrast rather than an opaque wash.

## Fixed interaction and layout contract

- Keep the default panel at 820×220 and centered below the menu bar.
- Keep the current header order: Clipio, search, Clear, Settings, Quit.
- Keep one horizontal row of 138×150 cards with 12-point spacing.
- Preserve shortcut badges, pin state, source app icon, relative time, text/image/color content, horizontal keyboard navigation, auto-scroll, hover preview, click-to-paste, and drag-out behavior.
- Preserve the existing selected-card semantics and accessibility identifiers.
- Do not add categories, tags, navigation chrome, or new toolbar actions.

## Material hierarchy

### 1. Tray: one clear lens

The panel is the largest and quietest glass surface.

- Use the native `NSGlassEffectView` regular style on macOS 26.
- Reduce the current ambient color wash from `0.18` to approximately `0.06` opacity.
- Prefer a nearly colorless top-left white highlight with only a faint cool-blue cast toward the lower-right.
- Use a 28-point continuous outer radius.
- Add a thin layered perimeter: bright white at top/left, faint cyan at right, and a very subtle pink spectral accent near the upper-right edge.
- Keep the shadow broad and soft. It should separate the shelf from the desktop without looking like a dark floating rectangle.

### 2. Cards: independent crystalline tiles

Cards remain visually distinct because the card shelf is Clipio's core browsing model.

- Keep 138×150 dimensions and 22-point continuous corners.
- On macOS 26, use native interactive `glassEffect` with a very low cool tint.
- Reduce the resting white fill and blue tint enough that wallpaper detail remains visible.
- Use a one-point luminous rim at rest; strengthen it on hover.
- Retain the two-point hover lift and soft shadow, but make the shadow less navy and more neutral.
- Do not place a milky overlay over image content. Let images stay crisp and clip them to the inner card shape.

### 3. Selection and hover

- Selected state remains unmistakable: a 2–2.5 point accent-blue outline plus a controlled cyan glow.
- Selection must not change card size or move neighboring cards.
- Hover may brighten the rim, increase glass response, lift by two points, and deepen the shadow slightly.
- Shortcut badges remain solid blue for dependable contrast; they are functional labels, not glass decoration.

### 4. Header controls

- Search and the three circular actions should read as smaller glass elements resting inside the larger tray.
- Keep the 32-point search height and 28-point action controls.
- Reduce blue tint in the search surface; use native vibrancy and a faint white rim.
- Keep icons monochrome white/primary. Color is reserved for selection and destructive confirmation, not decoration.

### 5. Card content and footer

- Text cards use semantic foreground colors and remain readable over bright and dark wallpapers.
- Footer remains 28 points high with source icon and time.
- Replace the visibly gray footer bar with a quieter local glass separator: a faint top highlight and minimal white fill.
- Image and color cards retain accurate source content. Glass belongs around content, not over it.

## Compatibility

- **macOS 26+:** use `NSGlassEffectView`, `glassEffect`, and a shared `GlassEffectContainer` for nearby custom glass elements.
- **Older macOS:** retain `NSVisualEffectView`/SwiftUI material fallback with the same hierarchy, radii, spacing, and restrained rim. Exact refraction is not expected, but the fallback must remain light and readable.
- Respect Reduce Transparency and Increased Contrast automatically through system materials and semantic foreground styles; avoid hard-coded translucency as the only contrast mechanism.

## Acceptance criteria

1. The shelf is visibly more transparent and less blue/gray than the current UI.
2. The desktop wallpaper clearly samples through both tray and card glass on macOS 26.
3. The outer tray and individual cards have distinct depth without looking neon or skeuomorphic.
4. Text, icons, footer metadata, and shortcut badges remain readable over both bright and dark backgrounds.
5. Selection, hover, keyboard navigation, auto-scroll, Clear/Shift-Clear All, Settings, Quit, pin ordering, preview, paste, and drag behavior remain unchanged.
6. The unsigned Debug build reports `BUILD SUCCEEDED`, existing unit tests pass, and a visual comparison is captured against the selected reference.

## Explicit non-goals

- Pixel-perfect reproduction of the generated wallpaper or sample clipboard contents.
- Custom shader-based refraction or chromatic aberration.
- Changing panel size, card density, typography scale, content model, or clipboard behavior.
- Removing the older macOS fallback.
