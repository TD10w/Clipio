# Clipboard Star candidate

2026-11-11: user is away from the computer and explicitly asked to build a candidate rather than wait for visual review. Confirmed product decisions are in docs/tasks/clipboard-star.md. The following provisional details are reversible and await founder experience.

## Behavior

- Clipboard Pin becomes Star, retaining existing pins and shortcuts. Collection Pin unchanged.
- All / Favorites is inside Clipboard; no third main shelf or new trash icon. Favorites include existing image/text/rich-text/color/file-reference content. Ordinary clear retains favorites; clear-all deletes them only after an explicit, unsuppressible warning.
- Single existing trash opens a menu with Clear History and Clear All (Including Favorites); Shift does not change the icon or click meaning. Existing clear-all keyboard action must also require confirmation.
- Manual filter changes keep query. External accepted copies, including repeats, prefer All on the next opening and clear the old query; they do not change the current open view. Replaying a Clipio card does not reset the view. Star/unstar does not navigate. A later manual filter choice takes precedence over earlier copy events. Remember preferred filter across launches. No new special shortcut.
- Optional names can be edited from a favorite's context menu and Settings, without changing copied bytes. Preserve existing generated/OCR title as fallback; naming image content must not be overwritten by OCR. Search names plus underlying generated content. Canceling a rename does nothing.
- Keep clipboard content representations and existing copy/paste/permission behavior. File favorites remain references, not backups.

## Approach

Reuse the existing optional pin marker for retention and legacy compatibility. Add one nullable favoriteName field instead of overwriting generated titles; this makes aliases independent of OCR and original content. Add a small persistent filter preference and session-only pending-search-reset state. Centralize filtering in History so navigation/shortcuts see the same items as the shelf. Native segmented Picker and Menu; no new toolbar icon or external dependency.

## Validation

TDD for filter/query behavior, external versus own copy, repeated copies, legacy pins, clear preservation, aliases/content identity and full-clear confirmation. Full isolated unit suite, required unsigned Debug build and built-resource check. Candidate only: no installation, real clipboard data, publication, computer use or mouse-driving UI tests. Existing real-store schema migration and native keyboard/visual acceptance remain separate gates before daily replacement.
