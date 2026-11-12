# Unpinned files rejected by attachment destinations

The owner reported that files in the collection shelf could only be dropped into a chat attachment composer after being pinned. The screenshot showed `Pasted text.txt` and a DMG in the collection. This correction allows ordinary files to negotiate copy as well as move, without requiring Pin. After the first fix, the owner also approved removing unpinned shelf entries when the destination accepts the drop, while preserving their original files.

## Initial attachment compatibility fix (8e30b20)

`CollectionStore.prepareExport` previously advertised move/delete for ordinary local references, while pinned-only exports advertised copy. A destination accepting only copy therefore had no supported operation for an ordinary reference. The source now offers copy alongside move. The existing completion path keeps ordinary references and their original files on a copy callback. Pin-only exports still offer only copy; batches containing Pin items still exclude delete.

Verification:

- Before the fix, both new attachment-destination regressions failed because copy negotiation returned no operation. Fixtures cover an ordinary TXT, a DMG and a mixed ordinary/Pin batch. Log: `/tmp/clipio-attachment-drag-red.log`.
- After the fix, all 188 unit tests passed, including attachment copy and original-file retention, move completion, Pin protection, cancellation and Trash cases. Log: `/tmp/clipio-attachment-drag-green.log`.
- Required Debug build succeeded. Log: `/tmp/clipio-attachment-drag-build.log`.
- Release build and deep strict signature verification passed. Candidate: `build/人工验收/attachment-drag-fix/Clipio.app`. Log: `/tmp/clipio-attachment-drag-release.log`.

These tests exercise the real export URLs and copy completion using synthetic files. They do not establish acceptance by the actual chat app or Finder's default choice when both move and copy are offered. Native desktop automation was unavailable in this session. Confirm unpinned attachment import, ordinary Finder move and pinned Finder copy with the built candidate before release. No message was sent and no release was published. After owner approval the initial fix was installed at `/Applications/Clipio.app`; signature, binary hash and running process were verified. Previous app: `/tmp/clipio-before-attachment-fix-3vxlurf3/Clipio.app`.

## Follow-up: consume accepted unpinned attachments

The owner approved these rules after the initial installation:

- A destination's successful copy completion removes the unpinned entry from the collection, without deleting its referenced original.
- Pinned entries, untouched entries, rejected drops and cancelled drags remain. A Pin added before completion also protects the entry.
- This uses AppKit's accepted-drop callback. Clipio cannot observe whether a chat message was ultimately sent or whether an asynchronous upload succeeded.
- Owned payloads already use independent outgoing staging copies, so removing their cards does not remove the files still being read by the destination.

Updated regressions reproduce the missing removal before the change, while retaining checks for attachment bytes, original-file safety, mixed Pin batches and persistence after reopening. A separate regression protects a Pin added after drag preparation. Red log: `/tmp/clipio-consume-attachment-red.log`.

All 189 unit tests passed after the change (`/tmp/clipio-consume-attachment-green.log`), and the required Debug build succeeded (`/tmp/clipio-consume-attachment-debug.log`).

The Release build and deep strict signature validation also passed (`/tmp/clipio-consume-attachment-release.log`). Candidate: `build/人工验收/attachment-consume-fix/Clipio.app`. The follow-up was installed at `/Applications/Clipio.app` and restarted; the running PID was 58563 and the installed executable matched the candidate SHA256 `9bebc43d68d2d352021edca8cf0aa7e3465fbed5ff111c888e1db56a78c6414c`. Previous version: `/tmp/clipio-before-consume-fix-jn1djh_x/Clipio.app`. Actual chat-app behavior remains for owner acceptance; no message was sent and no public release was made.
