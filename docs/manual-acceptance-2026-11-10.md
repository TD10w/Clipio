# November 10 focused manual acceptance

Local app: `../build/人工验收-20261110/Clipio测试版.app`. Synthetic files and separate source/destination folders are beside it in `测试素材/`.

Use the November 10 local build, not yesterday's preview. Exit the old Clipio first so panels and shortcuts cannot overlap. This is a local Debug build, not a public installer. Use disposable files in two test folders; never start with valuable originals.

1. Drag a test folder from Finder toward the top-center region. The welcoming entry should appear **below the notch** during the drag; approaching the card shelf should unfold it without entering the menu bar. Drop it into the collection.
2. Open a different Finder folder and drag the ordinary collected folder there. Confirm the **original source is gone**, destination contents are intact, and the collection item disappears only after the move. Do not infer movement from the card disappearing.
3. Import another test folder, Pin it, then drag out. Confirm source and destination both exist with identical contents and the Pin item remains in the collection.
4. Try a mixed ordinary/Pin batch. Only the ordinary original should move; Pin originals stay. Parent-folder/contained-child selections, including an unselected Pin child already in the collection, should instead display a clear instruction to drag them separately.
5. Cancel a drag with Escape, drop onto an invalid target, and cancel Finder's duplicate-name prompt. Originals and uncompleted collection items must remain. Check same-folder drops and a disposable folder on another disk separately.
6. Check the compact tray entry has no count and a complete lower-right edge, opens when clicked, and returns after closing the collection.
7. In Settings → Appearance → Glass material, compare Follow System and More Transparent. Check text remains readable; system Reduce Transparency must override the clearer option. Compare light/dark and Reduce Motion. These system preference changes are user actions, not automated in this run.
8. Check both shortcuts, switching with Tab, search and normal clipboard copying. Test browser images separately from local file movement; imported images are saved/staged copies.

Report “item number + what happened + what you expected.” Steps 2–5 require real Finder results; they have not been accepted by the automated run. Verification details: [evidence](acceptance-evidence-2026-11-10.md).
