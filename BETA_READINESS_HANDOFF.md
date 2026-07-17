# Clipio Beta-Readiness Handoff

Updated: 2026-07-17

## Continue From Here

- Repository: `https://github.com/TD10w/Clipio.git`
- Branch: `codex/beta-readiness`
- Local worktree used for this work: `/Users/dx/Documents/Agent/Claude Code/Clipio/.worktrees/beta-readiness`
- On another computer: clone/fetch the repository, then check out `codex/beta-readiness`.
- Do not recreate the work from `master`; the completed remediation is committed on this branch.

## Completed

1. Removed clipboard contents from feedback diagnostics, logs, and notifications. Errors now report safe metadata instead of copied text.
2. Added an Accessibility-permission gate before simulated paste. Clipio copies the selected item but does not send a paste keystroke without permission, and it explains how to enable permission.
3. Isolated UI tests from personal clipboard history by using a separate test bundle ID, private pasteboard, in-memory storage, and deterministic fixtures.
4. Added `scripts/release-beta.sh`, which fails closed unless signing, notarization, stapling, and Gatekeeper verification all succeed.
5. Hid updater controls because no update feed is configured for the beta.

The shelf pop-out and close animation was intentionally not changed. Dropzone, music display, and other new features were deferred until beta blockers are closed.

## Commits

- `0f634df` — keep clipboard contents out of feedback and logs
- `13ef7e0` — gate paste on Accessibility permission
- `12bfdea` — isolate shelf UI regression coverage
- `0be0638` — add fail-closed beta release pipeline
- `ffc7752` — hide unconfigured beta update controls

## Verification Already Completed

- Core/unit tests: 84 passed, 0 failed.
- `tests/beta-surface-tests.sh`: passed.
- `tests/release-beta-tests.sh`: passed.
- Required unsigned Debug build: `BUILD SUCCEEDED`.
- Focused shelf popup UI test: passed while the screen was unlocked.
- Full inherited UI suite: 15 passed and 21 failed. Do not treat this as 21 confirmed product defects. The failures mainly came from legacy Maccy assumptions, localized Chinese input, an unrelated Youdao Dictionary window interrupting automation, and brittle alert/window queries.

## Remaining Before External Beta

1. Run a small, focused beta UI checklist only: shelf open/close animation, text copy, image copy, search, clear-history confirmation, and paste behavior with and without Accessibility permission.
2. Stabilize only the tests covering that checklist. Do not spend time repairing every inherited Maccy UI test.
3. Obtain/install a valid Developer ID Application certificate and configure the notary keychain profile. The current Mac reported zero valid signing identities, so a real signed and notarized beta artifact could not be produced.
4. Run `scripts/release-beta.sh` with the real signing identity/profile and verify the produced archive on a clean Mac account or another Mac.

## Known UI-Test Notes

- Clear-history tests click the wrong button in the confirmation dialog. The smallest test-only approach is to launch those automated tests with `-suppressClearAlert true`, while retaining one manual confirmation-dialog check.
- Some keyboard tests ran under a Chinese input source and produced transformed text.
- Youdao Dictionary appeared as an interrupting window during several keyboard/search tests. Do not close unrelated user apps automatically; use a clean test session for the focused rerun.
- Several old tests expect the original Maccy popup lifecycle and exact item positions, which do not match Clipio's card shelf or deterministic fixture setup.

## Recommended Next Step

Start with the six-item focused manual/UI checklist above. If it passes, configure signing/notarization and create the first beta artifact. Keep new product features in a separate follow-up branch.
