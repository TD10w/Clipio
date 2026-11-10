# November 10 acceptance repair evidence

Base: PR #3 preview `842e22f`; branch `fix/acceptance-feedback-20261110`.
Authority: [November 9 feedback](acceptance-feedback-2026-11-09.md). Changes are local, not merged or released.

## Implemented behavior

- Ordinary local file/folder exports offer a native **move** operation. Finder/destination owns filesystem operations. Clipio never deletes original local files after a callback.
- Pin-only exports offer **copy**. Mixed move batches stage copies of Pin files/folders so their originals are never exposed to the batch's move operation. Web images always use independent staged exports.
- An ordinary reference is removed only after a move callback and its captured source path no longer exists. Cancelled, rejected, copy, link, delete, no-op, and partially completed moves retain unaffected references. If a move callback arrives first, an event-driven source watch reconciles later source disappearance. It expires after 30 minutes without inferring success; a slower/unobservable transfer leaves its card for manual cleanup.
- Selecting a moving parent and a contained child, or a parent containing any pinned local item in the collection (even unselected), is rejected before handoff.
- Copy-only destinations cannot accept ordinary local references in this mode. Pin first for copy/upload workflows. This is intentional: no silent fallback that misrepresents a copy as the requested move.
- The entry has no number, uses a stable native drop/hosting view with glass-rim insets, reveals a larger hint below the notch during supported external drags, and unfolds when the pointer approaches the shelf footprint. Release work is cancelled on a new drag; entry positioning follows the pointer's screen.
- Appearance settings offer Follow System and More Transparent native glass. System Reduce Transparency takes priority. Foreground opacity is unchanged. System fonts and original icon are preserved.

## Evidence and limits

- Three added regression tests failed against the previous implementation: unmoved-item consumption, mixed Pin original exposure, partial batch consumption. They passed after the fix. Full initial unit run: 115/115, `/tmp/clipio-nov10-green.log`.
- Nested parent/Pin-child rejection was separately observed RED in `/tmp/clipio-nov10-nested-red.log` before implementation.
- Native CUA inspected the icon-only entry with a complete rounded edge, opened the collection, confirmed a cancelled drag retained the synthetic item, and selected More Transparent then restored Follow System in the actual built settings pane.
- Native Finder drop verification did **not** complete reliably. CUA began drag sessions, but drops did not yield a successful operation; cancellation returned an empty operation. Two experimental XCTest Finder-drop cases (`testFinderMovesOrdinaryCollectionFile`, `testFinderCopiesPinnedCollectionFile`) timed out waiting for destination files in `/tmp/clipio-nov10-finder-ui.log`. They are diagnostic attempts, not passing evidence or shipped regression cases. The experiment was removed from the normal test suite. A previous manual-acceptance app was also found with an overlapping panel and was collapsed before further CUA attempts; its data was not edited.
- Finder actual move/copy, collision prompts, same-folder drops, cross-volume movement, browser imports, restart-scoped access, and visual behavior under system appearance/accessibility settings remain owner/device acceptance gates. Do not claim these passed from unit tests, simulated FileManager moves, or source masks.
- Independent final review found four Important issues: unselected pinned descendants, partial mixed owned-image consumption, delayed move reconciliation, and stale FloatingPanel mouse-release timers. Each was reproduced RED, then fixed; the full unit suite passed **120/120** in `/tmp/clipio-nov10-review-green.log`.
- First affected UI run: 10/13 passed; `testCollectionClearKeepsPinnedItem`, `testSearch`, `testUnpin` failed at the existing “Clipio did not pop up” launch gate. Log: `/tmp/clipio-nov10-final-regressions.log`. Final rerun and focused rechecks are recorded below.
- Deferred review minors: the shelf does not follow an already-open drag across displays; the generic ordinary-item caption also applies to owned web images; staging a large pinned folder in a mixed move is synchronous. These are not represented as accepted behavior.

## References

- Apple [drag source operation masks](https://developer.apple.com/documentation/appkit/nsdraggingsource/draggingsession(_:sourceoperationmaskfor:)) describe allowed operation negotiation.
- Apple [dragging files](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DragandDrop/Tasks/DraggingFiles.html) describes URL-based file handoff and sandbox scope.
- Apple [materials](https://developer.apple.com/design/human-interface-guidelines/materials) describes system preferences and accessibility adaptation; [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview) exposes regular/clear variants.

## Build and artifact verification

The required unsigned Debug command completed with **BUILD SUCCEEDED** (`/tmp/clipio-nov10-final-build.log`). The separately prepared manual Debug bundle also built successfully (`/tmp/clipio-nov10-manual-build.log`) and passed `codesign --verify --deep --strict`. Its identifier is `com.clipio.app.manualacceptancenov10`; it has not been launched or installed. All 31 main localization tables **inside the built app** contain the five added keys. Synthetic source/destination folders are supplied beside the app.

Final fresh-container verification re-ran all 120 unit tests successfully. Of 13 affected UI cases, 11 passed and two failed: `testCollectionDeleteDoesNotDeleteClipboardHistory` at “Clipio did not pop up”, and `testCollectionHasSeparateShortcutAndClipboardShortcutRoutesBack` waiting for a collection card. Log: `/tmp/clipio-nov10-fresh-final.log`. This is not an all-green UI result. Earlier UI reruns also had variable startup, hover and image-copy failures; logs remain `/tmp/clipio-nov10-ui-final.log` and `/tmp/clipio-nov10-final-regressions.log`.

## Implementation rulings

- Keep source-file operations under Finder/destination ownership; Clipio never cleans up a copy by deleting a local original.
- Ordinary-local move sessions intentionally reject copy-only destinations; Pin first to copy instead.
- Delayed-move observation is event-driven and capped at 30 minutes. After expiry or an unavailable watch, preserve the collection entry rather than infer success.
- Retain all manual acceptance gates and the three review minors above; no merge or release in this task.

The two failing UI cases were compared against untouched PR #3 `842e22f` in an archived source copy, using another isolated bundle ID: **2/2 passed** (`/tmp/clipio-nov10-baseline-comparison.log`). The same two cases were then rerun on the current unchanged repair tree: **2/2 passed** (`/tmp/clipio-nov10-ui-targeted-recheck.log`). The final evidence is 11 UI cases passed in the group plus 2 focused recheck passes, with earlier failures retained; this is not a claim of one clean 13-case run or a proof that the intermittent launch behavior is fixed.

## Later owner feedback on November 10

The owner reported oversized drag expansion, failure to dismiss on leaving/cancelling, an unsatisfactory Liquid Glass appearance, and Menu Bar movement during Tab switching. See [the source-faithful follow-up](acceptance-feedback-2026-11-10.md). Visual appearance is **not accepted**; the owner will arrange a different agent for the UI later. The tested running build is not yet identified. These are recorded reports, not reproduced root causes or accepted file-transfer outcomes. The revised checklist prioritizes file/data behavior and excludes repeated acceptance of these known unfixed UI items.

## Owner-reported file outcomes after the updated checklist

On November 10 the owner reported item 1 (ordinary move) and item 2 (Pin copy) passed. Within item 3, invalid-target drops and Escape cancellation were reported as having no problem. Same-name conflict cancellation remains untested. These are owner-reported outcomes for the current experience; the running bundle/revision was not independently identified. Do not generalize to cross-volume, batch, browser, restart, or the separate drag-UI dismissal issue. Source: [feedback and original wording](acceptance-feedback-2026-11-10.md).

### Observed same-name test outcome

After the owner said the test was done, read-only inspection found the source path absent, the original target contents unchanged, and an additional `冲突测试 copy.txt` containing the source contents. The November 10 manual bundle's persisted collection manifest had no matching collision-test item. Both contents survive, but this is a completed move with a second name, not evidence of cancellation. The actual dialog button selected remains unconfirmed; do not mark conflict cancellation passed or diagnose a cancellation bug without that answer. Two app copies were running; no files were restored or app data changed during inspection.

The owner subsequently confirmed **“keep both”**. The observed completed move with a renamed second file therefore passes the Keep Both case. Conflict cancellation remains untested; the earlier button-confirmation question is resolved.

### Subsequent owner acceptance

The owner subsequently reported same-name Cancel/Stop passed (“1. 没问题”), then ordinary-plus-Pin mixed batch drag-out passed (“2. 测试没问题”) after the operation was explained. Parent/child Pin protection remains a separate untested case. A new same-drop Stack grouping/expansion request is recorded for design, with hover versus click undecided; no implementation or acceptance is claimed for it.

### Final four owner-reported checks

The owner confirmed the next four cases passed: parent/child Pin protection, app quit/relaunch persistence and reuse, basic shortcuts/Tab/search/text-and-image clipboard behavior, and browser-image import/export/opening. The attached [parent/child protection screenshot](screenshots/2026-11-10-parent-pin-protection.png) shows the protective alert; disk safety for this case remains owner-reported rather than independently inferred from the screenshot. Cross-volume remains untested. App relaunch does not establish OS restart, another machine, all browser/sites, or release-artifact acceptance. Previously reported UI issues remain open.
