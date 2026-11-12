# Unpinned files rejected by attachment destinations

The owner reported that files in the collection shelf could only be dropped into a chat attachment composer after being pinned. The screenshot showed `Pasted text.txt` and a DMG in the collection. This correction allows ordinary files to negotiate copy as well as move, without requiring Pin.

`CollectionStore.prepareExport` previously advertised move/delete for ordinary local references, while pinned-only exports advertised copy. A destination accepting only copy therefore had no supported operation for an ordinary reference. The source now offers copy alongside move. The existing completion path keeps ordinary references and their original files on a copy callback. Pin-only exports still offer only copy; batches containing Pin items still exclude delete.

Verification:

- Before the fix, both new attachment-destination regressions failed because copy negotiation returned no operation. Fixtures cover an ordinary TXT, a DMG and a mixed ordinary/Pin batch. Log: `/tmp/clipio-attachment-drag-red.log`.
- After the fix, all 188 unit tests passed, including attachment copy and original-file retention, move completion, Pin protection, cancellation and Trash cases. Log: `/tmp/clipio-attachment-drag-green.log`.
- Required Debug build succeeded. Log: `/tmp/clipio-attachment-drag-build.log`.
- Release build and deep strict signature verification passed. Candidate: `build/人工验收/attachment-drag-fix/Clipio.app`. Log: `/tmp/clipio-attachment-drag-release.log`.

These tests exercise the real export URLs and copy completion using synthetic files. They do not establish acceptance by the actual chat app or Finder's default choice when both move and copy are offered. Native desktop automation was unavailable in this session. Confirm unpinned attachment import, ordinary Finder move and pinned Finder copy with the built candidate before release. No message was sent, no daily installation was replaced and no release was published.
