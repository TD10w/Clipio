# Candidate R2 fixes

User rejected segmented All/Favorites controls and reported Shift+Tab and Dock Trash did not work. Running candidate executable matches the original candidate hash; do not modify its extracted app or data.

1. Replace Picker with one plain star: outline All, gold fill Favorites; click and exact Shift+Tab share one toggle. Preserve plain Tab, composition, modal/sheet and Collection behavior; customized opening-shortcut bindings take precedence.
2. Root cause: previous .delete handler only observed path disappearance and never requested recycling. Apple Dragging Sources requires source handling for Dock Trash; call NSWorkspace.recycle for the exact allowed exported files, then remove only individually confirmed, actually-moved non-Pin items. Keep security scope alive until completion, preserve errors/partial results, no permanent deletion fallback. External cold-launch probing then proved selected-file read/write access is necessary: upgrade only user-selected file/folder scope and bookmarks, retain legacy grants until explicit Finder re-drop refresh.
3. Red/green tests: keyboard guards; recycle request routed from export completion; failure/partial/no-move paths; live Pin/descendant protection. One real NSWorkspace smoke test on uniquely named synthetic temporary content, no real user files or Trash enumeration. Restore only that test's returned Trash URL if allowed.
4. Full isolated suite, required build, built resource checks, independent read-only review. Prepare a new R2 package without touching/launching old candidate. Real Dock drag still needs observation if it cannot be exercised without computer use; do not overclaim it from callback tests.


## Verified root causes and review corrections

- Actual running R1 executable hash matches prepared R1; no build ambiguity. Shift+Tab was absent, not a broken installed binding.
- Old .delete handler never requested system recycling; new completeExport is used by the dragging source and calls NSWorkspace.recycle.
- A background-only sandbox probe with the same read-only entitlement/bookmark options returned Cocoa error 513 after a cold launch. Read/write selected-file entitlement and writable security-scoped bookmark succeeded for a synthetic external file and folder after cold launch. No user files or Trash enumeration were used.
- A probe compiled with the actual CollectionStore/CollectionItem/RuntimeEnvironment sources confirmed legacy readonly bookmark refresh through addFile, preserved card ID and Pin, then successfully recycled the explicitly unpinned synthetic item after a cold launch. Recycled files/folders were restored to their unique temporary locations.
- Review findings reproduced first: overlapping export releasing another lock, unreadable pinned child silently omitted, moved/deleted/recreated payload identity. Fixed busy ownership, metadata-only Pin location checks, fail-closed uncertain folder containment, and fresh resource/stat/birth identity snapshots.
- If any Pin location cannot be resolved, ordinary single-file exports remain possible, but folder moves/recycling fail closed rather than risk moving an unknown pinned descendant.
- Final 168 unit tests passed, including real NSWorkspace synthetic Trash/restore; required unsigned Debug and R2 signed preview builds succeeded. UI/Dock negotiation remains founder acceptance, not asserted by these backend checks.
