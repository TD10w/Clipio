# Collection Receipt Feedback Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline; one final independent read-only review. No implementation delegates.

**Goal:** Add the approved collection sound A, gentle bounce and transient checkmark after a fully successful new import batch.
**Architecture:** An in-memory batch tracker counts successful persisted IDs and failures across provider/promise inputs. A receipt generation in CollectionStore drives the existing nonactivating receiver panel and its sound; metadata reload and unrelated mutations never generate receipts.
**Tech Stack:** Swift, AppKit, SwiftUI, XCTest; no new dependency.
**Spec:** ../specs/2026-11-11-collection-receipt-design.md

## Global Constraints

- Only approved A audio and C bounce + B checkmark; no quantity text.
- No computer use, daily installation, publication or real user data tests.
- macOS 14+, Reduce Motion, no new permission or dependency.
- Build must succeed; bundle must contain the WAV. Keep 31 language tables consistent.

## Review Focus

- Duplicates, no-op batches, restored metadata: no sound or success signal.
- Partial/complete failure or failed manifest write: keep errors; no false full success.
- Concurrent provider imports: independent completion and no importingCount underflow.
- File promises may contain several files: wait for declared count and finish only once.
- A stale dismissal cannot hide a newer receipt; new drags remain usable.

### Task 1: Accurate batch completion

**Files:** CollectionStore.swift, CollectionImporter.swift, CollectionTests.swift.
**Interfaces:** `CollectionImportBatch(count:store:)`, `complete(id:error:)`; `CollectionStore.receiptGeneration` and `recordReceipt()`.
- [x] Add tests for seven-member success, empty/duplicate/full/partial failure, failed persistence, and independent interleaved batches.
- [x] Run isolated collection tests; confirm new completion behavior fails before implementation.
- [x] Implement shared tracker. Return persisted UUID from importer helpers; each provider completes once.
- [x] Confirm collection tests pass.

### Task 2: Native feedback and bundled sound

**Files:** CollectionAccessController.swift, NSSound+Named.swift, Clipio.xcodeproj/project.pbxproj, Sounds/Collect.wav, 31 Localizable.strings.
**Interfaces:** receipt generation observation updates receiver panel; promise callbacks feed the same tracker.
- [x] Add test for bundled 0.38s sound; inspect failure before registering resource.
- [x] Install the exact approved WAV as Collect.wav and register in project. Add optional NSSound lookup without force unwrap.
- [x] Observe successful batch events; show checkmark and bounce, play once, dismiss after 1.05s using generation guard. Do not activate or capture clicks. Respect Reduce Motion.
- [x] Route promises through tracker using declared file names; keep ordinary provider/shelf paths sharing the importer.
- [x] Run all unit tests, required unsigned Debug build, built-resource check, and independent final code review. Fix findings and rerun relevant checks.
- [x] Record limits, commit verified checkpoint, hand off without installation.
