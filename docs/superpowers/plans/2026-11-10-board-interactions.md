# Board interactions implementation plan

**Goal:** Align clipboard hover, expose removal, and keep the header stable when switching shelves.

**Scope update:** The owner cancelled manual ordering in both shelves during PR #10 review. Clipboard ordering and its database field have been removed; retain the existing sort settings. Earlier ordering work below is superseded.

**Architecture:** Keep clipboard data and collection file operations separate. Remove stale hover geometry, use one hover target for selection and preview, and persist ordering without changing clipboard payloads or deleting source files. Internal reorder must be distinguished from export, including stacks and search.

**Tech Stack:** SwiftUI, AppKit, SwiftData, collection manifest, XCTest.

- [ ] Reproduce stale geometry and hover changes with isolated tests; correct the identified cause and verify hover with a running app.
- [ ] Add an explicit clipboard remove action backed by existing deletion; test targeted removal.
- [x] Remove the cancelled clipboard manual ordering and database field; retain existing sorting.
- [ ] Collection ordering is deferred at the owner's request after the isolated manual test did not pass. The experimental collection changes were removed; existing file drag behavior remains in place.
- [ ] Build, run relevant isolated tests, and provide one consolidated experience checklist.
