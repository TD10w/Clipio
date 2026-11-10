# Board interactions implementation plan

**Goal:** Align clipboard hover, expose removal, and allow persistent ordering in both shelves.

**Architecture:** Keep clipboard data and collection file operations separate. Remove stale hover geometry, use one hover target for selection and preview, and persist ordering without changing clipboard payloads or deleting source files. Internal reorder must be distinguished from export, including stacks and search.

**Tech Stack:** SwiftUI, AppKit, SwiftData, collection manifest, XCTest.

- [ ] Reproduce stale geometry and hover changes with isolated tests; correct the identified cause and verify hover with a running app.
- [ ] Add an explicit clipboard remove action backed by existing deletion; test targeted removal.
- [ ] Implement persistent clipboard ordering with new copies first, preserving pins and existing data; test restart and duplicates.
- [ ] Implement persistent collection ordering including stacks without initiating a file export; test persistence, cancellation and file safety.
- [ ] Build, run relevant isolated tests, and provide one consolidated experience checklist.
