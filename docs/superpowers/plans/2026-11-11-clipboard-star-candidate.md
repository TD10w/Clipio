# Clipboard Star Candidate Implementation Plan

> **For agentic workers:** Use executing-plans inline, then one independent read-only whole-branch review.

**Goal:** Build the agreed Star behavior and reversible proposed controls while user is away.
**Architecture:** Existing pin storage keeps retention compatible; nullable alias separates names from content/OCR. History owns filtered search/navigation and reopening intent; Header owns one clear menu with explicit confirmation.
**Tech Stack:** SwiftData, SwiftUI, AppKit, Defaults, XCTest.
**Spec:** ../specs/2026-11-11-clipboard-star-design.md

## Constraints

- Preserve Clipboard / Collection distinction; no new trash icon, permission or dependency.
- All / Favorites retains query. No view jump on live external copy or Star.
- No installation/publication/computer use; synthetic isolated tests only.
- Resource changes in all 31 locales and required Debug build.

## Review Focus

- Hidden favorites cannot be selected with stale numeric or keyboard selection.
- Re-copied favorites preserve alias/marker and bytes; own-card copies do not reset opening intent.
- Deferred search work must use the latest filter, and mutations must not bypass filtering.
- Every clear-all entry, even with suppression enabled, must still explicitly warn about favorites.
- Empty favorites, unstarred last item, image aliases and original file references remain usable and honest.

### Task 1: History model and filter intent

Files: History.swift, HistoryItem.swift, HistoryItemDecorator.swift, Search.swift, Defaults.Keys+Names.swift, FloatingPanel.swift, HistoryTests.swift.
- [x] Add failing tests for filtered search, queries, external/own/repeat copy reopening, old pins, alias/content and ordinary clear.
- [x] Implement centralized filtering and one optional alias; preserve image/content formats and shortcut behavior.
- [x] Run targeted tests, fix regressions.

### Task 2: Controls and clear semantics

Files: HeaderView.swift, ListHeaderView.swift, CardItemView.swift, HistoryListView.swift, PinsSettingsPane.swift, AppState.swift, Footer.swift, FooterItem.swift, KeyHandlingView.swift, localization tables.
- [x] Add failing tests for unsuppressible clear-all through shared request method.
- [x] Implement segmented All/Favorites, star controls, optional rename, single-trash menu, explicit full-clear warning and Favorites settings identity.
- [x] Run all unit tests, required Debug build and built strings check.
- [x] Independent code review; reproduce/fix findings and rerun appropriate checks.
- [x] Record scope/limits and commit candidate without installation.
