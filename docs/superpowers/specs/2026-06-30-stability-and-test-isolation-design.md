# Clipio Stability and Test Isolation Design

## Goal

Fix the small stability issues found in the June 30 review while preserving Clipio's current appearance, speed, and interaction model. Future automated checks must not touch the owner's real clipboard history, system clipboard, running Clipio instance, or global shortcut.

## User-visible behavior

- Pinning and unpinning from a card must update the card order and shortcut badge immediately.
- Closing and immediately reopening the shelf must leave the newly opened shelf visible.
- The existing shelf design, animations, shortcuts, search behavior, drag behavior, and stored history format remain unchanged.

## Safe test mode

When Clipio starts for automated tests, it will enter an isolated test mode:

- It will not terminate or replace the owner's running Clipio.
- It will not register the global Clipio shortcut.
- It will not start the normal background clipboard watcher.
- Clipboard tests will use a private test pasteboard instead of the macOS system pasteboard.
- History tests will continue using an in-memory database and will never open the production SwiftData store.

The test-mode check will live in one small shared helper so the storage, app startup, shortcut, and clipboard paths agree on what "testing" means.

## Implementation boundaries

1. Route card pin controls through the existing `History.togglePin` operation rather than changing the item directly.
2. Give each shelf close animation an identity. Its completion is allowed to close the panel only if no newer open operation has superseded it.
3. Add the shared test-mode helper and suppress runtime-only side effects during tests.
4. Allow `Clipboard` to receive a pasteboard, defaulting to the real system pasteboard in normal use and a private named pasteboard in tests.
5. Re-enable the existing `HistoryTests` after isolation is verified.
6. Remove the unnecessary `Sendable` declaration from `AppState`; Clipio remains in Swift 5 mode and this prevents the known Swift 6 warning from becoming a future error.

## Data safety checks

Before and after the final test run, verification will compare production database record counts and modification state without reading clipboard contents. The system pasteboard change counter will also be compared without reading its contents. A passing result requires both production data and the system clipboard to remain untouched.

## Verification

- New regression tests first demonstrate the pin and close/reopen bugs.
- Clipboard tests pass using only the private pasteboard.
- All previously enabled tests pass.
- The 13 disabled history tests are restored and pass.
- The project-standard Debug build reports `BUILD SUCCEEDED`.
- No Swift 6 `AppState` Sendable warning remains.
- The production database and system pasteboard safety checks remain unchanged across the test run.

## Non-goals

- No visual redesign.
- No new product features.
- No database migration or history cleanup.
- No dependency upgrades.
- No changes to the owner's existing uncommitted UI work beyond the pin-control lines already in scope.
