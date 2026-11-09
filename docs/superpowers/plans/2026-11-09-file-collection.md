# File Collection Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans in this bound worktree. The founder authorized implementation here with provisional UI while the parent settles the global visual design.

**Goal:** Add a local file collection shelf with persistent references, owned web images, pinned retention, batch drag-out and separate shortcut entry points.

**Architecture:** Keep collection state separate from SwiftData clipboard history. An observable collection store owns a versioned atomic JSON manifest and security-scoped file bookmarks. Narrow AppKit bridges own drag-session completion and the compact notch entry; SwiftUI reuses the existing shelf shell and sizing.

**Tech Stack:** Swift, SwiftUI, AppKit, Foundation, ImageIO, existing KeyboardShortcuts.

**Spec:** `docs/plans/2026-11-09-dropzone-discussion.md`

## Global Constraints

- Use this T3-bound checkout and implement inline. No installer, release, provider calls or global restyling.
- Reference original local files and folders; own only imported image data.
- Ordinary items disappear only on accepted external drags. Pin items survive drag and clear.
- All remaining items survive restart. Invalid references remain visible and removable.
- Command+Shift+V opens clipboard and Command+Shift+C opens collection; Tab and one icon switch modes.
- Reuse current shelf dimensions, materials and system fonts pending parent UI work.
- Register every new Swift file in project.pbxproj.
- Test only synthetic files, ephemeral collection roots, in-memory clipboard storage and named test pasteboards.

## Review Focus

- Failed or cancelled exports retain every affected item; internal drops never consume items.
- Clearing owned images during or after drag does not invalidate the files handed to the destination.
- Persistence failure preserves the prior manifest and in-memory items; corrupt manifests are not silently overwritten.
- Moving/deleting files, duplicates and mixed successful/failed imports remain understandable and retryable.
- Tab works from search while input-method candidates keep their keys; two global shortcuts route consistently.

### Task 1: Collection storage and transfer

**Files:** Create `Clipio/CollectionItem.swift`, `Clipio/CollectionStore.swift`, `Clipio/CollectionImporter.swift`, `ClipioTests/CollectionTests.swift`. Modify `Clipio/Clipio.entitlements`, `Clipio.xcodeproj/project.pbxproj`.

**Interfaces:** `CollectionStore(directory:securityScoped:)`, `addFile(_:)`, `addImage(data:name:)`, `resolveURL(for:)`, `togglePin(_:)`, `remove(ids:)`, `clearUnpinned()`, `prepareExport(ids:)`, `finishExport(_:accepted:)`. Importer accepts `[NSItemProvider]` asynchronously and reports per-item failures.

- [x] Write and run failing isolated tests for restart, source file preservation, duplicate imports, invalid paths, pinned/ordinary completion, cancelled batch, owned image cleanup, corruption and failed writes.
- [x] Implement Codable item/manifest, scoped bookmark lifecycle, atomic mutation and staged image exports.
- [x] Add provider import with file URL priority, image representations and validated image-URL fallback.
- [x] Run collection tests and compile. Commit a working storage checkpoint.

### Task 2: Route the existing shelf

**Files:** Create `Clipio/CollectionShelfView.swift`, `Clipio/CollectionDragSource.swift`. Modify `Clipio/Observables/AppState.swift`, `Clipio/Observables/Popup.swift`, `Clipio/Views/ContentView.swift`, `Clipio/Views/HeaderView.swift`, `Clipio/Views/ListHeaderView.swift`, `Clipio/Settings/GeneralSettingsPane.swift`, `Clipio/Extensions/KeyboardShortcuts.Name+Shortcuts.swift` and localization tables.

**Interfaces:** AppState exposes the active shelf mode, collection and a mode-dependent search binding. Popup routes mode entry from global and local shortcut events. Collection drag source delegates selection and completed exports to the store.

- [x] Add tests for mode routing, Tab classification, filtering, selection and drag completion.
- [x] Implement one provisional switch icon, search, multi-selection, Pin, remove and clear confirmation within the current shell.
- [x] Add scoped Tab interception and both configurable shortcuts without forwarding collection actions to clipboard.
- [x] Run focused tests and compile. Commit a routing checkpoint.

### Task 3: Notch entry and end-to-end verification

**Files:** Create `Clipio/CollectionAccessController.swift`. Modify `Clipio/AppDelegate.swift`, `ClipioUITests/ClipioUITests.swift`, localization tables and pbxproj.

**Interfaces:** AppDelegate retains one access controller, started outside test mode. Controller observes item count and external drags, shows a compact top-center entry and opens the collection shelf without activating another app during drag.

- [x] Add synthetic UI fixtures and regressions for icon/Tab routing, search, pin protection and separate shortcuts, using named pasteboards and temporary files.
- [x] Implement drag detection and count entry with monitor cleanup, screen-change positioning and accepted drop handoff.
- [x] Run all unit tests, relevant UI regressions and the required Debug build. Review diff for scope, failure consistency, sandbox grants and test isolation.
- [x] Commit the verified checkpoint and report remaining device/Finder/browser acceptance separately from automated results.

## Execution notes

- The founder requested inline work initially. Self-review here respects that constraint; a separate reviewer can be requested later.
- Provisional UI is functional acceptance scaffolding for the parent's shared visual direction.

## Verified checkpoint

- Complete unit suite in the isolated `com.clipio.app.collectionunittests` host passed 103 tests. Logs at `/tmp/clipio-unit-final.log`.
- Collection icon/Tab routing, both shortcut routes, Pin protection on clear and collection deletion isolation passed four XCUITests. Result bundle at `/tmp/clipio-dropzone-ui/Logs/Test/Test-Clipio-2026.11.09_15-46-07-+0800.xcresult`.
- Nine affected clipboard regressions passed. Logs at `/tmp/clipio-ui-baseline-final.log`.
- Required unsigned Debug build passed. Logs at `/tmp/clipio-final-build.log`.
- Verified seven new Swift files are registered and all 31 built localizations contain the collection resources. New copy covers Chinese and English; remaining locales use English fallback.
- Review was performed inline to preserve this session's initial no-subagent constraint. Independent review and founder/device acceptance remain separate gates before release.

## Implementation decisions and remaining acceptance

- Image imports preserve their original supported raster format. Import limits are 64 MiB, 16,384 pixels per side and 64 million pixels in total, keeping untrusted image decoding bounded. Local file/folder references have no image-size limit.
- Export operations offer copy semantics, protecting original files. The destination's macOS drag result decides consumption of ordinary items; that result does not prove a subsequent chat message was sent or a remote upload completed.
- Owned images are staged for file handoff. Those temporary outgoing copies remain available to late-reading destinations and are pruned after 24 hours on the next startup/export. Tests stage these files under their own temporary root.
- Repeated local file imports retain the existing item and its Pin. Filtering removes hidden items from selection, preventing deletion of an invisible selection.
- Legacy default Command+Shift+C migrates once to Command+Shift+V; other custom or disabled clipboard shortcuts are preserved. Test shortcuts use all-modifier J/K to avoid the founder's running preview and installed Clipio.
- The provisional UI uses the current shelf shell. Final Liquid Glass styling, typography and icon direction belong to the parent design branch.
- Still to accept on device after UI integration: external Finder files/folders, real Safari/Chrome image and file-promise drags, dragging a mixed pinned/ordinary batch into Finder/chat apps, external sandbox grants across an app/OS restart, notch-entry positioning and cancel/drop motion.
- No installer, release or merge was performed.

## Parent integration follow-up

The parent integrated checkpoint `f27fac8` into `design/liquid-glass-system-20261109` at `3dce65d`, preserving mode-dependent search and routing while applying shared native materials and system typography. This is a design-preview branch pending founder visual approval.

An independent read-only review found late resource validation in URL/file-promise image imports and partial batch Pin state when a later manifest write fails. The parent addressed both before delivery.

- URL image imports check HTTP status, MIME and known size at the response boundary, cancel at the cumulative byte limit, disable response caching and have a total resource timeout.
- Promised image files are checked before opening, read with a byte cap, and prepared on the receiver's utility queue. The main thread only commits the prepared image.
- Multiple selected Pin states are committed atomically in one manifest write. Failed persistence leaves the entire in-memory selection unchanged for retry.
- Seven focused regressions cover early rejection, unfinished chunked transfers, valid byte preservation, unreadable oversized-file preflight, single-write batch Pin and retry. Regression failures were observed before the fixes. All 110 integrated unit tests passed.
- Initial integrated UI verification had one transient startup/open failure. Its isolated recheck passed, followed by a complete 13-test affected UI rerun with zero failures (`/tmp/clipio-integrated-ui-final.log`). Required unsigned Debug build also passed (`/tmp/clipio-integrated-final-build.log`).

Both review findings were fixed at `ac20752`. The parent treated batch Pin as an important consistency issue because retries can otherwise invert a previously successful subset. Four integrated native light/dark screenshots are recorded under `Designs/explorations/2026-11-09-liquid-glass/`. External application, sandbox restart and founder/device acceptance gates above remain open.
