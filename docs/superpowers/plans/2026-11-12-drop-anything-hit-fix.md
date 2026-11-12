# Drop intake and hit-target corrections

User confirmed that re-dropping the folder refreshes its access and outbound Trash then works. The new inbound goal covers files, folders, images, text and links, including references originating in Trash. Lightweight storage is approved: file/folder/video references, bounded saved content, bounded thumbnails, preview release.

- Native offscreen regression reproduced a wide neighboring image stealing the Star hit and card selection firing. Move Star outside card tap/drag surface and clip interaction shape. Same test now passes both star/unstar without card selection.
- Add UTF-8 text and web links with native drag/copy representations, persist small payload files through the existing ownedFileName manifest path for rollback compatibility. Keep physical file/video references and original bytes intact.
- Candidate defaults selected by implementer: image payload maximum 64 MiB, UTF-8 text 1 MiB, link 8 KiB, saved collection payload total 128 MiB, temporary outgoing staging total 128 MiB, thumbnail NSCache budget 32 MiB. Over-budget imports explain failure rather than evict retained content. These limits cover collection payloads and thumbnail caching, not the existing clipboard database or whole-process RAM.
- Downsample image data with ImageIO and release offscreen images. Avoid retaining original NSImage through resized drawing closures.
- Native drag intake must inspect offered operations and accepted types. Do not label inbound Trash as verified from ordinary-file callbacks. Record only operation masks/types/counts.
- User authorized temporary-file mouse testing, but cua.getState failed with Native pipe startup failed / browser access host unavailable. No pointer actions were performed. Continue isolated tests and ship explicit native-intake acceptance limits.

## R3 evidence and acceptance boundary

- Preserve native NSURL grants across asynchronous import; native intake logs only operation masks, types and counts. Inline image/text/link representations are preferred to file promises. UTF-16 and generic plain text are decoded as their registered types.
- Files/folders/videos retain references. A synthetic 2 GiB sparse video adds no saved media bytes. A synthetic Trash-origin file reference remains in Trash; this does not prove Finder mouse negotiation.
- A move-only source is declined because this design retains a reference without moving its file. If Finder Trash offers only move, restore the item to an ordinary folder first. Actual offered operations remain unverified.
- Bare virtual file promises expose no reliable pre-generation size/cancellation bound. They show a save-to-Finder instruction instead of producing an unknown-size hidden copy. Legacy abandoned promise directories older than 24 hours are pruned; recent copies are retained.
- Offscreen AppKit event tests cover Star/unstar beside a wide image and the collection Pin control. The full suite also covers text/link persistence and native pasteboard representations, capacity failures, staging cancellation, image downsampling and cache release.
- Review found generic/UTF-16 decoding and unbounded promised copies; both corrected. A pre-existing mouse-release regression used delayed event posting and could deliver the old release after a new drag; it now delivers the test event synchronously before starting the next drag.
- Real Finder/Trash drag testing was attempted twice but the native computer-use pipe failed to start. No mouse actions, app replacement, installation or publication occurred. R3 remains a candidate, pending actual inbound Trash, Star clicks and the five source types in the user's workflow.
- Final isolated suite: 184 tests, zero failures (`/tmp/clipio-r3-handoff-tests.log`). Required unsigned Debug build succeeded (`/tmp/clipio-r3-required-build.log`). Candidate bundle remains `com.clipio.app.candidate20261111`, build 6703, preserving R1/R2 candidate data; formal `com.clipio.app` is untouched.
