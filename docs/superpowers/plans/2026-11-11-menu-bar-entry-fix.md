# Collection menu-bar overlap fix

User approved this correction after a screenshot showed the idle collection pill covering another menu-bar icon. The implementation used a statusBar-level NSPanel positioned by screen coordinates rather than a system-reserved status item.

Approved behavior: use NSStatusItem for the nonempty collection's idle entry; retain the existing drag-only receiving panel below the menu bar. Keep item visibility independent of Clipboard/Collection Tab switches. Preserve import, spring-open, Pin and export behavior.

- [x] Prove a nonempty collection currently creates a visible idle overlay panel with a failing runtime regression.
- [x] Replace the idle overlay with a fixed-width system-managed status item, with accessible collection label and click action. Remove it when the controller is released.
- [x] Limit the floating panel to active file drags; its frame always lies below the menu bar/notch safe area.
- [x] Verify the regression, frame bounds on notched/non-notched/secondary screens, collection entry routing and Tab stability, onboarding, required Debug build and unit suite.
- [ ] Merge, rebuild 2.7.3 (65), sign and notarize new ZIP/DMG, validate extracted/mounted payloads, publish release and verify downloads. Earlier unpublished build 64 artifacts must not be uploaded.

No new product behavior, data migration or installer replacement is included. The guide and previously approved storage behavior remain unchanged.

Verification: the idle overlay test failed on the original implementation, then passed after switching to NSStatusItem. All 134 unit tests and the Tab geometry regression with the native entry enabled passed together. The six-case UI group had a shelf-startup timeout in `testCollectionHasSeparateShortcutAndClipboardShortcutRoutesBack`; the other five passed, including onboarding and collection preservation. The startup failure is retained in `/tmp/clipio-menu-entry-ui.log`; targeted recheck is recorded separately. Required Debug build log: `/tmp/clipio-menu-entry-final-debug.log`.

The shortcut test's first targeted recheck also timed out. Its `openShelf()` guard can mistake the nearly transparent prewarm panel for an already open shelf. The harness now waits for launch to open the real shelf using the same existing startup flag as the Tab regression. With that change the shortcut routing case passed (`/tmp/clipio-menu-entry-shortcut-ready.log`); no shortcut production code changed. The six UI cases therefore passed in batches, not a single all-green run. Independent read-only review found no Critical/Important issues. Empty → nonempty → empty native-item visibility is not separately automated; existing count observation is retained.
