# Clipio Onboarding Guide Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan inline. Steps use checkbox syntax for tracking.

**Goal:** New users can find the menu-bar entry and both shelf shortcuts without someone explaining them.

**Architecture:** A retained AppKit window controller hosts a three-page SwiftUI guide. AppDelegate presents it after startup; a durable Defaults flag prevents repeat automatic display. The existing settings gear gains a menu with Settings and Getting Started.

**Tech Stack:** SwiftUI, AppKit, Defaults, KeyboardShortcuts, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-11-onboarding-design.md`

## Global Constraints

- Use the approved English copy exactly; include matching entries in all 31 Localizable.strings tables.
- Use synthetic illustrations only; do not access real clipboard history in illustrations.
- Preserve data storage, file operations and shortcut behavior. New Swift files must be registered in the project.
- Work on `feature/onboarding-guide` in the existing checkout; no install, publication or merge in this task.

## Review Focus

- Skip, close and completion must all suppress future automatic presentation; manual reopening starts on page one.
- Unset and customized shortcuts must display their actual state, not the default shortcut.
- UI testing stays isolated and existing shelf regressions must not be obscured by the new window.
- Menu icon illustrations must reflect the chosen icon, including the scissors glyph rendering exception.
- The guide must remain legible in light/dark appearance and keyboard navigation must not switch shelves behind it.

## Task 1: Guide and lifecycle

**Files:** Create `Clipio/OnboardingController.swift`, `Clipio/Views/OnboardingView.swift`, `Clipio/Views/OnboardingIllustration.swift`, `ClipioUITests/OnboardingUITests.swift`. Modify `AppDelegate.swift`, `HeaderView.swift`, `Defaults.Keys+Names.swift`, 31 language tables, and `Clipio.xcodeproj/project.pbxproj`.

**Interfaces:** `OnboardingController.show()` resets to page one; `showIfNeeded()` uses the durable seen flag; completion closes and invokes an injected `onStart` closure. View callbacks handle dismiss/start; illustration receives page and selected MenuIcon.

- [x] Add UI regressions for first display, forward/back, completion opening Clipboard, skip/close persistence, manual reopening, custom and unset shortcuts.
- [x] Run the first-display test against the baseline and confirm failure because the guide is absent.
- [x] Implement the retained single window and three pages. Read actual shortcut descriptions on presentation. Persist seen on dismissal, including the window close button. Do not request permissions.
- [x] Add the gear menu entry and a fallback in General settings for users who hide shelf search/header. Keep normal tests free of automatic onboarding; explicitly enable it in new tests.
- [x] Run all unit tests and targeted onboarding/shelf UI regressions using a separate bundle identifier, in-memory storage, named test pasteboard and separate shortcuts.
- [x] Inspect built-app screenshots of all three pages and light/dark appearance; inspect shipped language resources.
- [x] Run the required Debug build, review changes, update evidence, and commit a working checkpoint.

## Execution ledger

- User approved the prototype and final copy. Implementing inline without another permission round.
- Existing checkout was clean; a feature branch keeps the main branch's code untouched. No new worktree or installation is necessary.
- The earlier description said an existing menu; the current app uses a direct gear button. Use a small gear menu and a General-settings fallback so Getting Started is discoverable even with shelf search hidden.
- 131 unit tests passed. Ten UI cases passed across the final group and a targeted recheck; the whole-group external-dialog/focus failures are retained in `docs/onboarding-handoff-2026-11-11.md`.
- Read-only independent review found no Critical/Important blockers. Progress VoiceOver copy was moved into language tables; appearance screenshots explicitly choose light/dark.
- Required Debug build and isolated ad-hoc preview build passed. All 31 built language tables contain the approved copy. Six synthetic guide screenshots retained in the repository.
- Hidden-icon recovery remains a manual acceptance item: launch-argument overrides cannot exercise mutable settings faithfully, and the attempted settings-tab transition flow did not reliably trigger the action. The direct General-settings re-open flow passed. No unrelated Settings animation change was added.
