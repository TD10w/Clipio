# November acceptance feedback implementation plan

> Execute inline with superpowers:executing-plans; preserve the agreed workflow and use isolated test storage.

**Goal:** Fix the four November 9 acceptance issues on the integrated PR #3 preview.
**Architecture:** Finder owns filesystem moves via native file URL drags. The collection snapshots export intent, stages protected copies for mixed Pin batches, and consumes normal local references only after the original leaves its captured location. A persistent notch-entry view receives drags with a padded native surface. Shared native glass follows the system, with an optional clear variant.
**Spec:** `docs/acceptance-feedback-2026-11-09.md`

## Constraints
- Never delete local originals after a drag callback. Failed/cancelled/no-op moves retain collection entries.
- All Pin originals survive. Web images remain owned/staged, distinct from file references.
- Preserve system fonts and original app icon. No installation, merge or release.
- Named clipboard, temporary data, alternate bundle ID for tests; required unsigned Debug build before handoff.

## Review focus
- Finder asynchronous/partial move, same-directory and collision cancellation retain entries still at original path.
- Mixed Pin/ordinary folders must never hand Pin originals to a move operation.
- Callback copy/link/delete must never consume an ordinary reference or remove an original.
- Old drag-release timer must not hide a new drag; view updates must preserve drop registration.
- Reduce transparency/motion, notch/multiple displays, and unchanged clipboard shortcuts.

### Task 1: Safe native export intent
Files: CollectionItem.swift, CollectionStore.swift, CollectionDragSource.swift, CollectionTests.swift.
Interface: CollectionExport snapshots entries and operation; finishExport(_:operation:) reconciles each result, retaining unchanged local references.
- [ ] Add failing tests for copy callback retaining local items, no-op move retaining entries, mixed pinned copy staging, actual destination moves and partial completion.
- [ ] Run isolated collection tests; expected failures against current copy-only/accepted-Boolean implementation.
- [ ] Implement explicit native move/copy policy and snapshot completion. Finder owns original-file changes; exports never remove originals themselves.
- [ ] Run unit suite and required build; commit.

### Task 2: Welcoming entry and system glass
Files: CollectionAccessController.swift, ContentView.swift, Defaults.Keys+Names.swift, AppearanceSettingsPane.swift, localization tables.
Interfaces: persistent hosting/drop views; entry below safe menu/notch area, wider during supported drag; system/clear glass preference.
- [ ] Remove numeric label, pad glass from panel bounds, preserve drop target identity.
- [ ] Animate reveal on external supported drag immediately; open full shelf on approach below notch, not menu-bar hover. Respect Reduce Motion and cancel pending release on new drag.
- [ ] Expose System/Clear native glass choice; respect system Reduce Transparency and keep foreground opaque.
- [ ] Build, run relevant UI suite and inspect native rendered entry/settings.

### Task 3: Verification and handoff
- [ ] Verify real Finder move, Pin copy, cancellation and temporary cross-volume destination where available, with synthetic files only.
- [ ] Run full unit suite, affected UI regressions and final required unsigned Debug build.
- [ ] Review final diff, update acceptance evidence and handoff, commit stable checkpoint. Clearly separate automated, native Finder and owner acceptance.
