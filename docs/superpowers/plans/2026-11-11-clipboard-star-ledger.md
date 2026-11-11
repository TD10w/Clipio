# Star candidate ledger

- Base 1bfb0f7; independent feature/clipboard-star worktree.
- Ruling: user's explicit request to build while away supersedes continuing the interview before implementation. No final visual acceptance is inferred.
- Provisional defaults: one trash menu, new external copy resets next opening, otherwise remember manual filter; no dedicated filter shortcut.
- Ruling: reuse pin storage, add only nullable optional alias to prevent user names being destroyed by OCR. Existing actual-store migration remains a gate before installation, not proved by synthetic tests.
- Baseline 134/134 unit tests passed. First feature regression run executed 21 History tests with 16 expected failing assertions (stubbed feature interfaces, no real data).
- Initial implementation passed all 140 unit tests. An older duplicate-copy test asserted a deleted decorator's stale identity; revised it to assert retained original text/title/pin instead of requiring stale UI identity.
- Independent read-only review found color detection incorrectly reading alias and regex anchors incorrectly spanning combined name/content. Added regressions; both failed on the reviewed implementation.
- Added invariant/path regressions for rename removing selected item from results and Collection->Clipboard entry with pending external-copy intent. The three follow-up tests produced five expected failing assertions.
- Fixes: infer color from original cached content; search alias/generated title as separate fields; reconcile hidden navigation selections centrally; apply opening preference on Clipboard re-entry as well as panel opening.
- Final Star source verification: all 144 unit tests passed; required unsigned Debug build succeeded. Built app has 31/31 tables with Star/full-clear keys.
