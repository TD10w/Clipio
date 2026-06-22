# Maccy Behavior Parity Design

## Goal

Keep Clipio's horizontal floating-card shelf while restoring the key interaction guarantees inherited from Maccy.

## Behavior

- Keyboard navigation visibly highlights the selected card.
- Moving selection with the keyboard scrolls the horizontal shelf to keep the selected card visible.
- Pinned cards respect the existing "pins at top" and "pins at bottom" preference.
- Keyboard navigation targets visible cards only; it never lands on hidden footer actions.
- Clear is available as a compact header button. Normal Clear preserves pinned items. Holding Shift exposes Clear All and removes every item after the existing confirmation flow.
- About remains available from the menu-bar menu and is not added to the shelf.
- Cards restore stable accessibility identifiers and values so UI tests can address text, image, file, and formatted clipboard entries.

## Structure

- `CardItemView` owns selected-card styling and accessibility metadata.
- `HistoryListView` owns visual ordering and scroll-to-selection behavior.
- `HeaderView` owns the compact Clear/Clear All control.
- `NavigationManager` receives a visible-history-only boundary for the shelf, rather than navigating into footer items that are not rendered.
- Existing `History.clear()` and `History.clearAll()` remain the only deletion implementations.

## Testing

- Add focused unit tests for shelf ordering and navigation boundaries before implementation.
- Update UI-test selectors for card accessibility and add coverage for keyboard selection visibility where XCTest supports it.
- Run the 56 core tests, the macOS UI test target, and the required unsigned Debug build.

## Non-goals

- No redesign of the shelf.
- No new history model or storage behavior.
- No reintroduction of Maccy's full footer or paste-stack UI.
- No About button inside the shelf.
