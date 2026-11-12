import AppKit
import KeyboardShortcuts
import XCTest
import SwiftUI
@testable import Clipio

final class CollectionTests: XCTestCase {
  private var root: URL!
  private var directory: URL { root.appendingPathComponent("collection") }

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    // Under the sandbox the test temp folder itself sits in ~/Library/Containers; keep
    // ordinary fixtures from being classed as another app's private storage.
    MainActor.assumeIsolated { CollectionImporter.appPrivateHome = "/nonexistent-clipio-test-home" }
  }

  override func tearDownWithError() throws {
    MainActor.assumeIsolated { CollectionImporter.appPrivateHome = CollectionImporter.realHomeDirectory }
    try FileManager.default.removeItem(at: root)
  }

  private func source(_ name: String = "example.txt") throws -> URL {
    let url = root.appendingPathComponent(name)
    try Data("original".utf8).write(to: url)
    return url
  }

  private func store() -> CollectionStore {
    CollectionStore(directory: directory, securityScoped: false)
  }

  @MainActor
  func testNonemptyCollectionDoesNotOverlayMenuBarWithIdlePanel() throws {
    let collection = store()
    _ = try collection.addFile(source())
    let existingWindows = Set(NSApp.windows.map(ObjectIdentifier.init))
    let controller = CollectionAccessController(store: collection)
    withExtendedLifetime(controller) {
      let newPanels = NSApp.windows.filter {
        $0 is NSPanel && !existingWindows.contains(ObjectIdentifier($0))
      }
      XCTAssertFalse(newPanels.contains { $0.isVisible && $0.level == .statusBar },
                     "An idle collection must not cover system menu-bar items with a floating panel")
    }
  }

  @MainActor
  func testCollectionEntryUsesNativeStatusButtonAndRoutesToCollection() throws {
    let collection = store()
    _ = try collection.addFile(source())
    let controller = CollectionAccessController(store: collection)
    XCTAssertTrue(controller.statusItem.isVisible)
    let button = try XCTUnwrap(controller.statusItem.button)
    XCTAssertEqual(button.accessibilityIdentifier(), "collection-status-item")
    let originalMode = AppState.shared.shelfMode
    defer { AppState.shared.switchShelf(to: originalMode) }
    AppState.shared.switchShelf(to: .clipboard)
    button.performClick(nil)
    XCTAssertEqual(AppState.shared.shelfMode, .collection)
    XCTAssertTrue(controller.statusItem.isVisible)
    AppState.shared.switchShelf(to: .clipboard)
    XCTAssertTrue(controller.statusItem.isVisible, "Tab must not remove the collection's reserved menu slot")
  }

  @MainActor
  func testDragReceiverStaysBelowMenuBarOnEveryScreen() {
    for (screen, inset) in [
      (NSRect(x: 0, y: 0, width: 1512, height: 982), CGFloat(38)),
      (NSRect(x: 0, y: 0, width: 1920, height: 1080), CGFloat(0)),
      (NSRect(x: -1920, y: -300, width: 1920, height: 1080), CGFloat(0))
    ] {
      for targeted in [false, true] {
        let frame = CollectionAccessController.dragEntryFrame(
          screenFrame: screen, safeAreaTop: inset, menuBarHeight: 24, targeted: targeted
        )
        XCTAssertLessThanOrEqual(frame.maxY, screen.maxY - max(inset, 24) - 8)
        XCTAssertEqual(frame.midX, screen.midX)
        XCTAssertTrue(screen.contains(frame))
      }
    }
  }

  func testReferencesOriginalAndRestoresPinsAfterRestart() throws {
    let original = try source()
    let collection = store()
    let id = try collection.addFile(original)
    try collection.togglePin(id)
    try Data("edited".utf8).write(to: original)

    let restored = store()
    XCTAssertEqual(restored.items.count, 1)
    XCTAssertTrue(restored.items[0].isPinned)
    XCTAssertEqual(try restored.resolveURL(for: id).resolvingSymlinksInPath(), original.resolvingSymlinksInPath())
    XCTAssertEqual(try String(contentsOf: restored.resolveURL(for: id), encoding: .utf8), "edited")
    XCTAssertNil(restored.items[0].ownedFileName)
  }

  func testRepeatedFileImportKeepsIdentityAndPin() throws {
    let original = try source()
    let collection = store()
    let id = try collection.addFile(original)
    try collection.togglePin(id)
    XCTAssertEqual(try collection.addFile(original), id)
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertTrue(collection.items[0].isPinned)
  }

  func testFoldersAreReferencesAndClearNeverDeletesSources() throws {
    let folder = root.appendingPathComponent("folder")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let collection = store()
    _ = try collection.addFile(folder)
    try collection.clearUnpinned()
    XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    XCTAssertTrue(store().items.isEmpty)
  }

  func testMissingFileStaysVisibleAndExportFailsWithoutConsumingBatch() throws {
    let original = try source()
    let collection = store()
    let id = try collection.addFile(original)
    let other = try collection.addFile(source("other.txt"))
    try FileManager.default.removeItem(at: original)
    XCTAssertThrowsError(try collection.prepareExport(ids: [id, other]))
    XCTAssertEqual(collection.items.count, 2)
    collection.refreshAvailability()
    XCTAssertTrue(collection.unavailableIDs.contains(id))
  }

  func testCancelledExportKeepsOrdinaryAndPinnedItems() throws {
    let collection = store()
    let first = try collection.addFile(source())
    let pinned = try collection.addFile(source("pinned.txt"))
    try collection.togglePin(pinned)
    let export = try collection.prepareExport(ids: [first, pinned])
    try collection.finishExport(export, operation: [])
    XCTAssertEqual(store().items.count, 2)
  }

  func testAcceptedExportRemovesOnlyExportedUnpinnedItems() throws {
    let collection = store()
    let original = try source()
    let ordinary = try collection.addFile(original)
    let pinned = try collection.addFile(source("pinned.txt"))
    let untouched = try collection.addFile(source("untouched.txt"))
    try collection.togglePin(pinned)
    let export = try collection.prepareExport(ids: [ordinary, pinned])
    try FileManager.default.moveItem(at: original, to: root.appendingPathComponent("destination.txt"))
    try collection.finishExport(export, operation: .move)
    XCTAssertEqual(Set(store().items.map(\.id)), [pinned, untouched])
  }

  func testAcceptedButUnmovedLocalFileRemainsInCollection() throws {
    let original = try source()
    let collection = store()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    try collection.finishExport(export, operation: .move)
    XCTAssertEqual(store().items.map(\.id), [id])
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
  }

  func testCopyAndLinkCallbacksCannotConsumeOrdinaryReferences() throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    for operation: NSDragOperation in [.copy, .link, .delete, []] {
      let export = try collection.prepareExport(ids: [id])
      XCTAssertTrue(export.operation.contains(.move))
      XCTAssertFalse(export.operation.contains(.copy))
      try collection.finishExport(export, operation: operation)
      XCTAssertEqual(collection.items.map(\.id), [id])
      XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
    }
  }

  func testPinnedOnlyOffersCopyAndKeepsOriginalAfterDestinationCopy() throws {
    let original = try source()
    let collection = store()
    let id = try collection.addFile(original)
    try collection.togglePin(id)
    let export = try collection.prepareExport(ids: [id])
    XCTAssertEqual(export.operation, .copy)
    try FileManager.default.copyItem(at: XCTUnwrap(export.urls.first), to: root.appendingPathComponent("copy.txt"))
    try collection.finishExport(export, operation: .copy)
    XCTAssertEqual(collection.items.map(\.id), [id])
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
  }

  func testUnpinnedFileOffersTrashWithoutOfferingCopy() throws {
    let collection = store()
    let id = try collection.addFile(source())
    let export = try collection.prepareExport(ids: [id])
    defer { export.endAccess() }
    XCTAssertTrue(export.operation.contains(.delete), "Dock Trash negotiates delete, not move")
    XCTAssertTrue(export.operation.contains(.move))
    XCTAssertFalse(export.operation.contains(.copy))
  }

  func testMixedPinnedBatchDoesNotOfferTrash() throws {
    let collection = store()
    let ordinary = try collection.addFile(source())
    let pinned = try collection.addFile(source("pinned.txt"))
    try collection.togglePin(pinned)
    let export = try collection.prepareExport(ids: [ordinary, pinned])
    XCTAssertFalse(export.operation.contains(.delete))
    try collection.finishExport(export, operation: .delete)
    XCTAssertEqual(Set(store().items.map(\.id)), [ordinary, pinned])
    XCTAssertEqual(try String(contentsOf: collection.resolveURL(for: pinned), encoding: .utf8), "original")
  }

  @MainActor
  func testTrashCallbackRemovesOnlyFilesThatActuallyLeftTheirExportedLocation() async throws {
    let collection = store()
    let batch = UUID()
    let original = try source("trashed.txt")
    let removed = try collection.addFile(original, batch: batch)
    let retainedURL = try source("retained.txt")
    let retained = try collection.addFile(retainedURL, batch: batch)
    let export = try collection.prepareExport(ids: [removed, retained])
    // Simulate the destination moving one member. Never use the user's Trash.
    let destination = root.appendingPathComponent("destination.txt")
    await collection.completeExport(export, operation: .delete) { _, finish in
      do {
        try FileManager.default.moveItem(at: original, to: destination)
        finish([original: destination], CocoaError(.fileWriteNoPermission))
      } catch { finish([:], error) }
    }
    XCTAssertEqual(store().items.map(\.id), [retained])
    XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "original")
    XCTAssertEqual(try String(contentsOf: retainedURL, encoding: .utf8), "original")
  }

  @MainActor
  func testTrashCompletingAfterCallbackIsReconciled() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    let destination = root.appendingPathComponent("destination.txt")
    await collection.completeExport(export, operation: .delete) { _, finish in finish([original: destination], nil) }
    XCTAssertEqual(collection.items.map(\.id), [id])
    try FileManager.default.moveItem(at: original, to: root.appendingPathComponent("destination.txt"))
    let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in collection.items.isEmpty }, object: nil)
    await fulfillment(of: [removed], timeout: 2)
    XCTAssertTrue(store().items.isEmpty)
  }

  @MainActor
  func testOwnedImageOffersTrashAndKeepsCardUntilOutgoingFileLeaves() async throws {
    let collection = store()
    let bitmap = try XCTUnwrap(NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    let id = try collection.addImage(data: data, name: "web")
    let export = try collection.prepareExport(ids: [id])
    XCTAssertTrue(export.operation.contains(.delete))
    XCTAssertTrue(export.operation.contains(.copy))
    let outgoing = try XCTUnwrap(export.urls.first)
    let destination = root.appendingPathComponent("image.png")
    await collection.completeExport(export, operation: .delete) { _, finish in
      XCTAssertEqual(collection.items.map(\.id), [id])
      do {
        try FileManager.default.moveItem(at: outgoing, to: destination)
        finish([outgoing: destination], nil)
      } catch { finish([:], error) }
    }
    XCTAssertTrue(store().items.isEmpty)
    XCTAssertEqual(try Data(contentsOf: destination), data)
  }

  func testMovingParentProtectsUnselectedPinnedChild() throws {
    let collection = store()
    let parent = root.appendingPathComponent("parent")
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let child = parent.appendingPathComponent("pin.txt")
    try Data("protected".utf8).write(to: child)
    let parentID = try collection.addFile(parent)
    let childID = try collection.addFile(child)
    try collection.togglePin(childID)
    XCTAssertThrowsError(try collection.prepareExport(ids: [parentID]))
    XCTAssertEqual(try String(contentsOf: child, encoding: .utf8), "protected")
  }

  func testPartialMixedMoveKeepsUnmovedOwnedImage() throws {
    let collection = store()
    let original = try source()
    let ordinary = try collection.addFile(original)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    let image = try collection.addImage(data: XCTUnwrap(bitmap.representation(using: .png, properties: [:])), name: "web")
    let export = try collection.prepareExport(ids: [ordinary, image])
    try FileManager.default.moveItem(at: original, to: root.appendingPathComponent("destination.txt"))
    try collection.finishExport(export, operation: .move)
    XCTAssertEqual(collection.items.map(\.id), [image])
    XCTAssertNoThrow(try collection.resolveURL(for: image))
  }

  func testMoveCompletingAfterCallbackIsReconciled() throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    try collection.finishExport(export, operation: .move)
    XCTAssertEqual(collection.items.map(\.id), [id])
    try FileManager.default.moveItem(at: original, to: root.appendingPathComponent("destination.txt"))
    let removed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in collection.items.isEmpty }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [removed], timeout: 2), .completed)
    XCTAssertTrue(store().items.isEmpty)
  }

  func testOldMouseReleaseCannotEndNewPanelDrag() throws {
    let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), onClose: {}) { EmptyView() }
    panel.isDragging = true
    let released = try XCTUnwrap(NSEvent.mouseEvent(
      with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0
    ))
    // Deliver the old release before starting the next drag. Posting it leaves
    // delivery to a later run-loop turn, which can occur after the new drag.
    NSApp.sendEvent(released)
    let checked = expectation(description: "old release cannot clear a new drag")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel.isDragging = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      XCTAssertTrue(panel.isDragging)
      checked.fulfill()
    }
    wait(for: [checked], timeout: 2)
  }

  func testMovingParentCannotAlsoExportItsPinnedChild() throws {
    let collection = store()
    let folder = root.appendingPathComponent("parent")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let child = folder.appendingPathComponent("pinned.txt")
    try Data("protected".utf8).write(to: child)
    let parentID = try collection.addFile(folder)
    let childID = try collection.addFile(child)
    try collection.togglePin(childID)
    XCTAssertThrowsError(try collection.prepareExport(ids: [parentID, childID]))
    XCTAssertEqual(collection.items.count, 2)
    XCTAssertEqual(try String(contentsOf: child, encoding: .utf8), "protected")
  }

  func testMixedMoveStagesPinnedFolderInsteadOfExposingOriginal() throws {
    let collection = store()
    let original = try source()
    let ordinary = try collection.addFile(original)
    let folder = root.appendingPathComponent("pinned folder")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("protected".utf8).write(to: folder.appendingPathComponent("child.txt"))
    let pinned = try collection.addFile(folder)
    try collection.togglePin(pinned)
    let export = try collection.prepareExport(ids: [ordinary, pinned])
    defer { export.endAccess() }
    let pinnedURL = try XCTUnwrap(export.urls.first { $0.lastPathComponent == "pinned folder" })
    XCTAssertNotEqual(pinnedURL.resolvingSymlinksInPath(), folder.resolvingSymlinksInPath())
    XCTAssertEqual(try String(contentsOf: pinnedURL.appendingPathComponent("child.txt"), encoding: .utf8), "protected")
  }

  func testPartialMoveRetainsOnlyUnmovedOrdinaryReferences() throws {
    let collection = store()
    let movedURL = try source("moved.txt")
    let moved = try collection.addFile(movedURL)
    let retained = try collection.addFile(source("retained.txt"))
    let export = try collection.prepareExport(ids: [moved, retained])
    let target = root.appendingPathComponent("destination")
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try FileManager.default.moveItem(at: movedURL, to: target.appendingPathComponent("moved.txt"))
    try collection.finishExport(export, operation: .move)
    XCTAssertEqual(store().items.map(\.id), [retained])
    XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("moved.txt"), encoding: .utf8), "original")
  }

  func testOwnedImageExportSurvivesRemovalAndClearProtectsPins() throws {
    let collection = store()
    let bitmap = try XCTUnwrap(NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    let owned = try collection.addImage(data: data, name: "web image")
    let pinned = try collection.addFile(source())
    try collection.togglePin(pinned)
    let export = try collection.prepareExport(ids: [owned])
    let outgoing = try XCTUnwrap(export.urls.first)
    try collection.clearUnpinned()
    XCTAssertTrue(FileManager.default.fileExists(atPath: outgoing.path))
    XCTAssertEqual(store().items.map(\.id), [pinned])
    try collection.finishExport(export, operation: .move)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outgoing.path))
  }

  func testInvalidImageNeverCreatesEntry() throws {
    let collection = store()
    XCTAssertThrowsError(try collection.addImage(data: Data("not an image".utf8), name: "bad.png"))
    XCTAssertTrue(collection.items.isEmpty)
  }

  func testCorruptManifestIsPreservedAndMutationsAreBlocked() throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let manifest = directory.appendingPathComponent("items.json")
    let corrupt = Data("broken".utf8)
    try corrupt.write(to: manifest)
    let collection = store()
    XCTAssertNotNil(collection.lastError)
    XCTAssertThrowsError(try collection.addFile(source()))
    XCTAssertEqual(try Data(contentsOf: manifest), corrupt)
  }

  func testFailedPersistenceKeepsMemoryAndPriorManifest() throws {
    let collection = store()
    let id = try collection.addFile(source())
    let moved = root.appendingPathComponent("saved")
    try FileManager.default.moveItem(at: directory, to: moved)
    try Data("blocking file".utf8).write(to: directory)
    XCTAssertThrowsError(try collection.togglePin(id))
    XCTAssertFalse(collection.items[0].isPinned)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: moved, to: directory)
    XCTAssertFalse(store().items[0].isPinned)
  }
  @MainActor
  func testMixedProviderImportKeepsValidFilesAndReportsFailures() async throws {
    let collection = store()
    let url = try source()
    let valid = NSItemProvider(item: url as NSURL, typeIdentifier: "public.file-url")
    let unsupported = NSItemProvider()
    await CollectionImporter.collect([valid, unsupported], into: collection)
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertEqual(collection.importingCount, 0)
    XCTAssertNotNil(collection.lastError)
    XCTAssertEqual(try collection.resolveURL(for: collection.items[0].id).resolvingSymlinksInPath(), url.resolvingSymlinksInPath())
  }

  @MainActor
  func testShelfSwitchKeepsSearchesIndependent() {
    let state = AppState(history: History(), footer: Footer(), collection: store())
    state.activeSearchQuery = "clipboard search"
    state.switchShelf(to: .collection)
    state.activeSearchQuery = "collection search"
    state.switchShelf(to: .clipboard)
    XCTAssertEqual(state.activeSearchQuery, "clipboard search")
    state.switchShelf(to: .collection)
    XCTAssertEqual(state.activeSearchQuery, "collection search")
  }

  func testShiftTabOnlyTogglesFavoritesInClipboardMainView() {
    XCTAssertTrue(Popup.isFavoriteSwitch(keyCode: 48, modifiers: .shift, composing: false, mode: .clipboard, editing: false))
    for flags: NSEvent.ModifierFlags in [[], .command, [.shift, .command], [.shift, .option], [.shift, .control]] {
      XCTAssertFalse(Popup.isFavoriteSwitch(keyCode: 48, modifiers: flags, composing: false, mode: .clipboard, editing: false))
    }
    XCTAssertFalse(Popup.isFavoriteSwitch(keyCode: 48, modifiers: .shift, composing: true, mode: .clipboard, editing: false))
    XCTAssertFalse(Popup.isFavoriteSwitch(keyCode: 48, modifiers: .shift, composing: false, mode: .collection, editing: false))
    XCTAssertFalse(Popup.isFavoriteSwitch(keyCode: 48, modifiers: .shift, composing: false, mode: .clipboard, editing: true))
    XCTAssertFalse(Popup.isFavoriteSwitch(keyCode: 0, modifiers: .shift, composing: false, mode: .clipboard, editing: false))
  }

  @MainActor
  func testTrashDropActuallyRequestsRecyclingBeforeRemovingCard() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    let target = root.appendingPathComponent("recycled.txt")
    var requests = 0
    await collection.completeExport(export, operation: .delete) { urls, finish in
      requests += 1
      XCTAssertEqual(urls, [original])
      XCTAssertEqual(collection.items.map(\.id), [id])
      XCTAssertTrue(collection.isExporting)
      do {
        try FileManager.default.moveItem(at: original, to: target)
        finish([original: target], nil)
      } catch { finish([:], error) }
    }
    XCTAssertEqual(requests, 1)
    XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "original")
    XCTAssertTrue(store().items.isEmpty)
    XCTAssertFalse(collection.isExporting)
  }

  @MainActor
  func testRecycleFailureKeepsOriginalAndReportsError() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    await collection.completeExport(export, operation: .delete) { _, finish in
      finish([:], CocoaError(.fileWriteNoPermission))
    }
    XCTAssertEqual(collection.items.map(\.id), [id])
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
    XCTAssertNotNil(collection.lastError)
    XCTAssertFalse(collection.isExporting)
  }

  @MainActor
  func testPartialRecycleConsumesOnlySystemConfirmedItems() async throws {
    let collection = store()
    let first = try source("one.txt")
    let second = try source("two.txt")
    let a = try collection.addFile(first)
    let b = try collection.addFile(second)
    let export = try collection.prepareExport(ids: [a, b])
    let target = root.appendingPathComponent("recycled.txt")
    await collection.completeExport(export, operation: .delete) { _, finish in
      do {
        try FileManager.default.moveItem(at: first, to: target)
        finish([first: target], CocoaError(.fileWriteNoPermission))
      } catch { finish([:], error) }
    }
    XCTAssertEqual(store().items.map(\.id), [b])
    XCTAssertEqual(try String(contentsOf: second, encoding: .utf8), "original")
    XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "original")
    XCTAssertNotNil(collection.lastError)
  }

  @MainActor
  func testPinAddedAfterDragStartedPreventsTrashRequest() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    try collection.togglePin(id)
    var requested = false
    await collection.completeExport(export, operation: .delete) { _, finish in
      requested = true; finish([:], nil)
    }
    XCTAssertFalse(requested)
    XCTAssertEqual(collection.items.map(\.id), [id])
    XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
  }

  @MainActor
  func testSystemRecycleMovesAndRestoresOnlyItsSyntheticFile() async throws {
    let collection = store()
    let original = try source("Clipio-r2-recycle-\(UUID().uuidString).txt")
    let marker = "Clipio R2 synthetic recycle test \(UUID().uuidString)"
    try Data(marker.utf8).write(to: original)
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    var returned: URL?
    await collection.completeExport(export, operation: .delete) { urls, finish in
      NSWorkspace.shared.recycle(urls) { moved, error in
        returned = moved[original]
        finish(moved, error)
      }
    }
    XCTAssertNil(collection.lastError)
    let trashURL = try XCTUnwrap(returned)
    print("CLIPIO_R2_SYNTHETIC_TRASH_URL=\(trashURL.absoluteString)")
    let accessed = trashURL.startAccessingSecurityScopedResource()
    defer { if accessed { trashURL.stopAccessingSecurityScopedResource() } }
    defer {
      if !FileManager.default.fileExists(atPath: original.path) {
        try? FileManager.default.moveItem(at: trashURL, to: original)
      }
    }
    XCTAssertEqual(try String(contentsOf: trashURL, encoding: .utf8), marker)
    XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
    XCTAssertTrue(collection.items.isEmpty)
    try FileManager.default.moveItem(at: trashURL, to: original)
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), marker)
  }

  @MainActor
  func testNewPinnedDescendantProtectsParentAfterDragStarted() async throws {
    let collection = store()
    let parent = root.appendingPathComponent("folder")
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let child = parent.appendingPathComponent("child.txt")
    try Data("protected".utf8).write(to: child)
    let parentID = try collection.addFile(parent)
    let childID = try collection.addFile(child)
    let export = try collection.prepareExport(ids: [parentID])
    try collection.togglePin(childID)
    var requested = false
    await collection.completeExport(export, operation: .delete) { _, finish in requested = true; finish([:], nil) }
    XCTAssertFalse(requested)
    XCTAssertEqual(try String(contentsOf: child, encoding: .utf8), "protected")
  }

  @MainActor
  func testUnconfirmedRecycleKeepsCardAndReportsFailure() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    await collection.completeExport(export, operation: .delete) { _, finish in finish([:], nil) }
    XCTAssertEqual(collection.items.map(\.id), [id])
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "original")
    XCTAssertNotNil(collection.lastError)
  }

  @MainActor
  func testReplacementAtOldDragPathCannotBeRecycled() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    let moved = root.appendingPathComponent("moved-original.txt")
    try FileManager.default.moveItem(at: original, to: moved)
    try Data("replacement".utf8).write(to: original)
    var requested = false
    await collection.completeExport(export, operation: .delete) { _, finish in requested = true; finish([:], nil) }
    XCTAssertFalse(requested)
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "replacement")
    XCTAssertEqual(try String(contentsOf: moved, encoding: .utf8), "original")
    XCTAssertEqual(collection.items.map(\.id), [id])
  }

  @MainActor
  func testSecondExportCannotReleaseFirstPendingRecycleLock() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let first = try collection.prepareExport(ids: [id])
    let second = try collection.prepareExport(ids: [id])
    let started = expectation(description: "First recycle awaits system")
    var release: (([URL: URL], Error?) -> Void)?
    let pending = Task { await collection.completeExport(first, operation: .delete) { _, finish in
      release = finish; started.fulfill()
    } }
    await fulfillment(of: [started], timeout: 2)
    XCTAssertTrue(collection.isExporting)
    XCTAssertThrowsError(try collection.prepareExport(ids: [id]))
    await collection.completeExport(second, operation: .delete) { _, finish in finish([:], CocoaError(.userCancelled)) }
    XCTAssertTrue(collection.isExporting, "Rejected second completion cannot unlock the first operation")
    XCTAssertThrowsError(try collection.togglePin(id))
    release?([:], CocoaError(.userCancelled))
    await pending.value
    XCTAssertFalse(collection.isExporting)
  }

  @MainActor
  func testUnreadablePinnedChildStillProtectsParent() async throws {
    let collection = store()
    let parent = root.appendingPathComponent("parent-protected")
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let child = parent.appendingPathComponent("pinned.txt")
    try Data("protected".utf8).write(to: child)
    let parentID = try collection.addFile(parent)
    let childID = try collection.addFile(child)
    let export = try collection.prepareExport(ids: [parentID])
    try collection.togglePin(childID)
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: child.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: child.path) }
    XCTAssertFalse(FileManager.default.isReadableFile(atPath: child.path))
    XCTAssertThrowsError(try collection.prepareExport(ids: [parentID]))
    var requested = false
    await collection.completeExport(export, operation: .delete) { _, finish in requested = true; finish([:], nil) }
    XCTAssertFalse(requested)
    XCTAssertTrue(FileManager.default.fileExists(atPath: parent.path))
  }

  @MainActor
  func testDeletedAndRecreatedDragSourceCannotBeRecycled() async throws {
    let collection = store()
    let original = try source()
    let id = try collection.addFile(original)
    let export = try collection.prepareExport(ids: [id])
    let held = try FileHandle(forReadingFrom: original)
    defer { try? held.close() }
    try FileManager.default.removeItem(at: original)
    try Data("replacement".utf8).write(to: original)
    var requested = false
    await collection.completeExport(export, operation: .delete) { _, finish in requested = true; finish([:], nil) }
    XCTAssertFalse(requested)
    XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "replacement")
  }

  @MainActor
  func testPlainTextAndLinksAreSavedWithoutImageDownload() async throws {
    let collection = store()
    let text = "hello\nworld"
    let link = try XCTUnwrap(URL(string: "mailto:clipio-test@example.invalid"))
    await CollectionImporter.collect([
      NSItemProvider(item: text as NSString, typeIdentifier: "public.utf8-plain-text"),
      NSItemProvider(item: link as NSURL, typeIdentifier: "public.url")
    ], into: collection)
    XCTAssertEqual(collection.items.count, 2)
    XCTAssertEqual(collection.receiptGeneration, 1)
    let payloads = try collection.items.compactMap { try collection.payload(for: $0.id) }
    XCTAssertTrue(payloads.contains(.text(text)))
    XCTAssertTrue(payloads.contains(.link(link)))
    XCTAssertEqual(try store().items.compactMap { try store().payload(for: $0.id) }.count, 2)
  }

  func testSavedPayloadQuotaCountsBytesAndDoesNotDeleteRetainedContent() throws {
    let collection = CollectionStore(directory: directory, securityScoped: false, ownedByteLimit: 8)
    let id = try collection.addText("four")
    try collection.togglePin(id)
    XCTAssertEqual(collection.ownedStorageBytes, 4)
    XCTAssertThrowsError(try collection.addText("12345"))
    XCTAssertEqual(collection.items.map(\.id), [id])
    XCTAssertEqual(try collection.payload(for: id), .text("four"))
    XCTAssertTrue(collection.items[0].isPinned)
  }

  func testFailedPayloadManifestWriteCleansOnlyNewOwnedFile() throws {
    let broken = CollectionStore(directory: directory, securityScoped: false) { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
    XCTAssertThrowsError(try broken.addText("value"))
    XCTAssertTrue(broken.items.isEmpty)
    XCTAssertEqual(broken.ownedStorageBytes, 0)
  }

  func testVideoReferenceDoesNotSaveOrReadVideoBytes() throws {
    let file = root.appendingPathComponent("large.mov")
    FileManager.default.createFile(atPath: file.path, contents: Data())
    let handle = try FileHandle(forWritingTo: file)
    try handle.truncate(atOffset: 2 * 1024 * 1024 * 1024)
    try handle.close()
    let collection = store()
    let id = try collection.addFile(file)
    XCTAssertNil(collection.items[0].ownedFileName)
    XCTAssertEqual(collection.ownedStorageBytes, 0)
    XCTAssertEqual(try collection.resolveURL(for: id).standardizedFileURL, file.standardizedFileURL)
  }

  @MainActor
  func testNativeFileIntakeKeepsReferencesAndSharesOneReceipt() async throws {
    let collection = store()
    let a = try source("one.txt")
    let b = try source("two.txt")
    await CollectionImporter.collectFiles(CollectionFileDrop(urls: [a, b]), fallbacks: [], into: collection)
    XCTAssertEqual(collection.items.count, 2)
    XCTAssertEqual(collection.receiptGeneration, 1)
    XCTAssertTrue(collection.items.allSatisfy { $0.ownedFileName == nil })
    XCTAssertEqual(collection.ownedStorageBytes, 0)
  }

  @MainActor
  func testTrashedFileCanBeCollectedAsReferenceWithoutMovingOrDuplicating() async throws {
    let original = try source("Clipio-r3-inbound-\(UUID().uuidString).txt")
    var returned: NSURL?
    try FileManager.default.trashItem(at: original, resultingItemURL: &returned)
    let trash = try XCTUnwrap(returned as URL?)
    let access = trash.startAccessingSecurityScopedResource()
    defer { if access { trash.stopAccessingSecurityScopedResource() } }
    defer { try? FileManager.default.moveItem(at: trash, to: original) }
    let collection = CollectionStore(directory: directory)
    await CollectionImporter.collectFiles(CollectionFileDrop(urls: [trash]), fallbacks: [], into: collection)
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertNil(collection.lastError)
    XCTAssertEqual(collection.ownedStorageBytes, 0)
    XCTAssertTrue(FileManager.default.fileExists(atPath: trash.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
    let id = try XCTUnwrap(collection.items.first?.id)
    let restored = CollectionStore(directory: directory)
    XCTAssertEqual(try restored.resolveURL(for: id).standardizedFileURL, trash.standardizedFileURL)
  }

  @MainActor
  func testReferenceNegotiationNeverPromisesAMoveForAMoveOnlySource() {
    XCTAssertEqual(CollectionImporter.referenceOperation(offered: [.copy, .move]), .copy)
    XCTAssertEqual(CollectionImporter.referenceOperation(offered: .link), .link)
    XCTAssertEqual(CollectionImporter.referenceOperation(offered: .generic), .generic)
    XCTAssertTrue(CollectionImporter.referenceOperation(offered: .move).isEmpty)
    XCTAssertTrue(CollectionImporter.referenceOperation(offered: []).isEmpty)
    XCTAssertTrue(CollectionImporter.accepts(types: [.string]))
    XCTAssertTrue(CollectionImporter.accepts(types: [.init("NSFilenamesPboardType")]))
  }

  func testPayloadDragAndCopyKeepNativeTextAndFileRepresentations() throws {
    let collection = store()
    let link = try XCTUnwrap(URL(string: "https://example.invalid/profile"))
    let id = try collection.addLink(link)
    let export = try collection.prepareExport(ids: [id], forCopy: true)
    defer { export.endAccess() }
    let copied = HistoryItem(contents: try collection.clipboardContents(for: export))
    XCTAssertEqual(copied.text, link.absoluteString)
    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }
    let writer = CollectionPayloadWriter(fileURL: try XCTUnwrap(export.urls.first), payload: .link(link))
    XCTAssertTrue(board.writeObjects([writer]))
    XCTAssertEqual(board.string(forType: .string), link.absoluteString)
    XCTAssertEqual(board.string(forType: .URL), link.absoluteString)
    let files = try XCTUnwrap(board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])
    XCTAssertEqual(files.first?.standardizedFileURL, export.urls.first?.standardizedFileURL)
  }

  func testStagingQuotaRejectsMixedCopiesAndCancellationCleansOwnCopies() throws {
    let collection = CollectionStore(directory: directory, securityScoped: false, stagingByteLimit: 4)
    let normal = try collection.addFile(source("normal.txt"))
    let pinned = try collection.addFile(source("pinned.txt"))
    try collection.togglePin(pinned)
    XCTAssertThrowsError(try collection.prepareExport(ids: [normal, pinned]))
    let copy = try collection.prepareExport(ids: [normal, pinned], forCopy: true)
    XCTAssertTrue(copy.stagedDirectories.isEmpty)
    try collection.finishExport(copy, operation: [])
    XCTAssertEqual(collection.items.count, 2)
    let text = try collection.addText("abc")
    let staged = try collection.prepareExport(ids: [text])
    let outgoing = try XCTUnwrap(staged.urls.first)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outgoing.path))
    try collection.finishExport(staged, operation: [])
    XCTAssertFalse(FileManager.default.fileExists(atPath: outgoing.path))
    XCTAssertEqual(try collection.payload(for: text), .text("abc"))
  }

  func testOversizeTextIsRefusedBeforeStorage() {
    let collection = store()
    XCTAssertThrowsError(try collection.addText(String(repeating: "x", count: 1024 * 1024 + 1)))
    XCTAssertEqual(collection.ownedStorageBytes, 0)
  }

  @MainActor
  func testUTF16AndGenericTextRepresentationsAreCollected() async throws {
    let collection = store()
    let first = NSItemProvider()
    let second = NSItemProvider()
    let value = "你好 🌟"
    let unicode = try XCTUnwrap(value.data(using: .utf16LittleEndian))
    first.registerDataRepresentation(forTypeIdentifier: "public.utf16-plain-text", visibility: .all) { done in done(unicode, nil); return nil }
    second.registerDataRepresentation(forTypeIdentifier: "public.plain-text", visibility: .all) { done in done(Data("generic text".utf8), nil); return nil }
    await CollectionImporter.collect([first, second], into: collection)
    let payloads = try collection.items.compactMap { try collection.payload(for: $0.id) }
    XCTAssertTrue(payloads.contains(.text(value)))
    XCTAssertTrue(payloads.contains(.text("generic text")))
  }

  func testAbandonedLegacyPromiseCopiesArePrunedWhileFreshCopiesStay() throws {
    let temporary = FileManager.default.temporaryDirectory
    let old = temporary.appendingPathComponent("Clipio-Promises-\(UUID().uuidString)")
    let fresh = temporary.appendingPathComponent("Clipio-Promises-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: old); try? FileManager.default.removeItem(at: fresh) }
    try Data("abandoned test copy".utf8).write(to: old.appendingPathComponent("test.txt"))
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -90000)], ofItemAtPath: old.path)
    _ = store()
    XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
  }

  func testTabOnlySwitchesWithoutModifiersAndOutsideComposition() {
    XCTAssertTrue(Popup.isShelfSwitch(keyCode: 48, modifiers: [], composing: false))
    XCTAssertFalse(Popup.isShelfSwitch(keyCode: 48, modifiers: .command, composing: false))
    XCTAssertFalse(Popup.isShelfSwitch(keyCode: 48, modifiers: [], composing: true))
    XCTAssertFalse(Popup.isShelfSwitch(keyCode: 0, modifiers: [], composing: false))
  }

  func testMovedFileFollowsBookmark() throws {
    let original = try source()
    let collection = store()
    let id = try collection.addFile(original)
    let moved = root.appendingPathComponent("renamed.txt")
    try FileManager.default.moveItem(at: original, to: moved)
    XCTAssertEqual(try collection.resolveURL(for: id).resolvingSymlinksInPath(), moved.resolvingSymlinksInPath())
    XCTAssertEqual(try store().resolveURL(for: id).resolvingSymlinksInPath(), moved.resolvingSymlinksInPath())
  }

  @MainActor
  func testImageProviderOwnsBytesAndSurvivesRestart() async throws {
    let collection = store()
    let bitmap = try XCTUnwrap(NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    let provider = NSItemProvider(item: data as NSData, typeIdentifier: "public.png")
    await CollectionImporter.collect([provider], into: collection)
    let restored = store()
    XCTAssertEqual(restored.items.count, 1)
    XCTAssertNotNil(restored.items.first?.ownedFileName)
    XCTAssertNotNil(NSBitmapImageRep(data: try Data(contentsOf: restored.resolveURL(for: restored.items[0].id))))
  }

  func testExpiredOutgoingCopiesArePrunedButRecentHandoffsRemain() throws {
    let collection = store()
    let outgoing = collection.outgoingDirectory
    let old = outgoing.appendingPathComponent("old")
    let recent = outgoing.appendingPathComponent("recent")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: recent, withIntermediateDirectories: true)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -90000)], ofItemAtPath: old.path)
    collection.pruneOldExports()
    XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: recent.path))
  }

  func testFilteringCannotLeaveHiddenItemsSelectedForDeletion() throws {
    let collection = store()
    let first = try collection.addFile(source("alpha.txt"))
    let second = try collection.addFile(source("beta.txt"))
    collection.selectedIDs = [first, second]
    collection.searchQuery = "alpha"
    XCTAssertEqual(collection.selectedIDs, [first])
    collection.searchQuery = "no match"
    XCTAssertTrue(collection.selectedIDs.isEmpty)
  }

  func testLegacyDefaultShortcutMigratesWithoutOverwritingCustomKeys() {
    let original = KeyboardShortcuts.Name.popup.shortcut
    defer { KeyboardShortcuts.setShortcut(original, for: .popup) }
    KeyboardShortcuts.setShortcut(.init(.c, modifiers: [.command, .shift]), for: .popup)
    Popup.migrateLegacyDefaultShortcut()
    XCTAssertEqual(KeyboardShortcuts.Name.popup.shortcut, .init(.v, modifiers: [.command, .shift]))
    let custom = KeyboardShortcuts.Shortcut(.j, modifiers: [.command, .shift, .option])
    KeyboardShortcuts.setShortcut(custom, for: .popup)
    Popup.migrateLegacyDefaultShortcut()
    XCTAssertEqual(KeyboardShortcuts.Name.popup.shortcut, custom)
    KeyboardShortcuts.setShortcut(nil, for: .popup)
    Popup.migrateLegacyDefaultShortcut()
    XCTAssertNil(KeyboardShortcuts.Name.popup.shortcut)
  }

  @MainActor
  func testBatchPinCommitsOnceThroughAppState() throws {
    var pinWrites = 0
    var recordingPins = false
    let collection = CollectionStore(directory: directory, securityScoped: false) { data, url in
      if recordingPins {
        pinWrites += 1
        if pinWrites == 2 { throw CocoaError(.fileWriteOutOfSpace) }
      }
      try data.write(to: url, options: .atomic)
    }
    let first = try collection.addFile(source())
    let second = try collection.addFile(source("second.txt"))
    collection.selectedIDs = [first, second]
    let state = AppState(history: History(), footer: Footer(), collection: collection)
    state.switchShelf(to: .collection)
    recordingPins = true

    state.togglePin()

    XCTAssertEqual(pinWrites, 1)
    XCTAssertTrue(collection.items.allSatisfy(\.isPinned))
    XCTAssertNil(collection.lastError)
    XCTAssertTrue(store().items.allSatisfy(\.isPinned))
  }

  @MainActor
  func testFailedBatchPinCanRetryWithoutReversingAnyItem() throws {
    var failWrites = false
    let collection = CollectionStore(directory: directory, securityScoped: false) { data, url in
      if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
      try data.write(to: url, options: .atomic)
    }
    let first = try collection.addFile(source())
    let second = try collection.addFile(source("second.txt"))
    collection.selectedIDs = [first, second]
    let state = AppState(history: History(), footer: Footer(), collection: collection)
    state.switchShelf(to: .collection)
    failWrites = true
    state.togglePin()
    XCTAssertTrue(collection.items.allSatisfy { !$0.isPinned })

    failWrites = false
    state.togglePin()
    XCTAssertTrue(collection.items.allSatisfy(\.isPinned))
    XCTAssertTrue(store().items.allSatisfy(\.isPinned))
  }

  func testOversizedPromisedImageIsRejectedBeforeOpeningData() throws {
    let url = root.appendingPathComponent("oversized.png")
    FileManager.default.createFile(atPath: url.path, contents: Data())
    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: UInt64(CollectionImage.maximumByteCount + 1))
    try handle.close()
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path) }

    XCTAssertThrowsError(try CollectionImage(contentsOf: url)) { error in
      guard let collectionError = error as? CollectionError else {
        XCTFail("An oversized file must be rejected before the attempted read")
        return
      }
      guard case .invalidImage = collectionError else {
        XCTFail("Unexpected preflight error")
        return
      }
    }
  }

  func testRemoteNonImageIsRejectedAtResponse() async {
    await assertBoundedDownloadRejects("not-image")
  }

  func testRemoteAdvertisedOversizeIsRejectedAtResponse() async {
    await assertBoundedDownloadRejects("oversized")
  }

  func testRemoteChunkedOversizeIsRejectedBeforeEndOfStream() async {
    await assertBoundedDownloadRejects("chunked")
  }

  func testRemoteBytesWithinLimitArePreserved() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CollectionImageURLProtocol.self]
    let data = try await CollectionImporter.downloadImage(
      URL(string: "https://clipio.invalid/valid")!, configuration: configuration, maximumBytes: 64
    )
    XCTAssertEqual(data, Data([1, 2, 3, 4]))
  }

  private func assertBoundedDownloadRejects(_ path: String) async {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CollectionImageURLProtocol.self]
    let finished = expectation(description: "Reject invalid download before the server finishes")
    let task = Task {
      do {
        _ = try await CollectionImporter.downloadImage(
          URL(string: "https://clipio.invalid/\(path)")!, configuration: configuration, maximumBytes: 64
        )
        if !Task.isCancelled { XCTFail("Invalid download was accepted") }
      } catch {
        if !Task.isCancelled { XCTAssertTrue(error is CollectionError) }
      }
      finished.fulfill()
    }
    await fulfillment(of: [finished], timeout: 2)
    task.cancel()
    _ = await task.result
  }


  // MARK: Drops from apps' private storage (Messages)

  private func pngData() throws -> Data {
    let bitmap = try XCTUnwrap(NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
  }

  private func provider(url: URL, image: Data?) -> NSItemProvider {
    let provider = NSItemProvider(item: url as NSURL, typeIdentifier: "public.file-url")
    if let image {
      provider.registerDataRepresentation(forTypeIdentifier: "public.png", visibility: .all) { completion in
        completion(image, nil)
        return nil
      }
    }
    return provider
  }

  @MainActor
  func testAppPrivateLocationsAreDetected() {
    let home = "/Users/someone"
    XCTAssertTrue(CollectionImporter.isAppPrivate(
      URL(fileURLWithPath: "/Users/someone/Library/Messages/Attachments/84/04/x/photo.png"), home: home))
    XCTAssertFalse(CollectionImporter.isAppPrivate(URL(fileURLWithPath: "/Users/someone/Desktop/photo.png"), home: home))
    XCTAssertFalse(CollectionImporter.isAppPrivate(URL(fileURLWithPath: "/Volumes/Disk/photo.png"), home: home))
  }

  func testUnreadableURLWithImageBytesBecomesOwnedImageCopy() async throws {
    let collection = store()
    let missing = root.appendingPathComponent("Messages/Attachments/clipio-warm.png")
    await CollectionImporter.collect([provider(url: missing, image: try pngData())], into: collection)
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertNotNil(collection.items[0].ownedFileName, "kept as Clipio's own copy, not a reference")
    XCTAssertEqual(collection.items[0].name, "clipio-warm.png")
    XCTAssertNil(collection.lastError)
  }

  @MainActor
  func testAppPrivateURLIsCopiedEvenWhenReadableAndOriginalStays() async throws {
    let collection = store()
    // A readable file in an app's ~/Library storage must not become a movable reference.
    let previousHome = CollectionImporter.appPrivateHome
    CollectionImporter.appPrivateHome = root.path
    defer { CollectionImporter.appPrivateHome = previousHome }
    let attachments = root.appendingPathComponent("Library/Messages/Attachments")
    try FileManager.default.createDirectory(at: attachments, withIntermediateDirectories: true)
    let file = attachments.appendingPathComponent("photo.png")
    try pngData().write(to: file)
    XCTAssertTrue(CollectionImporter.isAppPrivate(file))
    await CollectionImporter.collect([provider(url: file, image: try pngData())], into: collection)
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertNotNil(collection.items[0].ownedFileName)
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
  }

  func testOrdinaryFileStaysAReferenceEvenWithImageBytes() async throws {
    let collection = store()
    let file = try source("photo.png")
    await CollectionImporter.collect([provider(url: file, image: try pngData())], into: collection)
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertNil(collection.items[0].ownedFileName)
  }

  // MARK: Stacks (same-drop batches)

  func testOneMultiItemDropFormsOneStackInDropOrderAndNextDropStaysSeparate() async throws {
    let collection = store()
    let names = (1...7).map { "photo\($0).txt" }
    let urls = try names.map { try source($0) }
    await CollectionImporter.collect(urls.map { NSItemProvider(item: $0 as NSURL, typeIdentifier: "public.file-url") }, into: collection)
    let later = try source("later.txt")
    await CollectionImporter.collect([NSItemProvider(item: later as NSURL, typeIdentifier: "public.file-url")], into: collection)

    XCTAssertEqual(collection.items.count, 8)
    XCTAssertNil(collection.items[0].batchID, "a single-item drop is never a Stack")
    let entries = collection.visibleEntries
    XCTAssertEqual(entries.count, 2)
    guard case .stack(let batch, let members) = entries[1] else { return XCTFail("expected a Stack") }
    XCTAssertEqual(members.map(\.name), names)
    XCTAssertEqual(members.count, 7)

    collection.toggleExpanded(batch)
    let expanded = collection.visibleEntries
    XCTAssertEqual(expanded.count, 1 + 1 + 7)
    guard case .collapseHandle(_, 7) = expanded[1] else { return XCTFail("expected collapse handle") }
  }

  func testStacksSurviveRestartAndLegacyManifestStillLoads() throws {
    let batch = UUID()
    let collection = store()
    try collection.addFile(source("a.txt"), batch: batch)
    try collection.addFile(source("b.txt"), batch: batch)
    XCTAssertEqual(store().items.map(\.batchID), [batch, batch])

    // A manifest written before Stacks existed has no batchID key.
    let manifest = directory.appendingPathComponent("items.json")
    var json = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as! [String: Any]
    json["items"] = (json["items"] as! [[String: Any]]).map { $0.filter { $0.key != "batchID" } }
    try JSONSerialization.data(withJSONObject: json).write(to: manifest)
    let legacy = store()
    XCTAssertEqual(legacy.items.count, 2)
    XCTAssertNil(legacy.lastError)
    XCTAssertTrue(legacy.items.allSatisfy { $0.batchID == nil })
  }

  @MainActor
  func testReceiptOnlyAfterEntireNewBatchHasPersisted() throws {
    let collection = store()
    let batch = CollectionImportBatch(count: 2, store: collection)
    let first = try collection.addFile(source("first.txt"))
    batch.complete(id: first)
    XCTAssertEqual(collection.receiptGeneration, 0)
    XCTAssertEqual(collection.importingCount, 1)
    let second = try collection.addFile(source("second.txt"))
    batch.complete(id: second)
    XCTAssertEqual(collection.receiptGeneration, 1)
    XCTAssertEqual(collection.importingCount, 0)
    batch.complete(id: second)
    XCTAssertEqual(collection.receiptGeneration, 1)
    XCTAssertEqual(collection.importingCount, 0)
    XCTAssertEqual(store().receiptGeneration, 0, "Restoring saved items must not replay success")
  }

  @MainActor
  func testConcurrentImportFailureCannotConfirmOrCancelAnotherBatch() throws {
    let collection = store()
    let good = CollectionImportBatch(count: 2, store: collection)
    let partial = CollectionImportBatch(count: 2, store: collection)
    good.complete(id: try collection.addFile(source("good1.txt")))
    partial.complete(id: try collection.addFile(source("partial.txt")))
    partial.complete(error: CollectionError.unsupportedDrop)
    XCTAssertEqual(collection.receiptGeneration, 0, "Partial failures must not claim complete success")
    XCTAssertEqual(collection.importingCount, 1)
    XCTAssertNotNil(collection.lastError)
    good.complete(id: try collection.addFile(source("good2.txt")))
    XCTAssertEqual(collection.receiptGeneration, 1)
    XCTAssertEqual(collection.importingCount, 0)
    XCTAssertEqual(collection.items.count, 3)
  }

  @MainActor
  func testProviderBatchReceiptsExcludeDuplicateEmptyAndFailedImports() async throws {
    let collection = store()
    let url = try source()
    let provider = { NSItemProvider(item: url as NSURL, typeIdentifier: "public.file-url") }
    await CollectionImporter.collect([provider()], into: collection)
    XCTAssertEqual(collection.receiptGeneration, 1)
    await CollectionImporter.collect([provider()], into: collection)
    await CollectionImporter.collect([], into: collection)
    await CollectionImporter.collect([NSItemProvider()], into: collection)
    XCTAssertEqual(collection.receiptGeneration, 1)
    XCTAssertEqual(collection.importingCount, 0)
    try collection.clearUnpinned()
    await CollectionImporter.collect([provider()], into: collection)
    XCTAssertEqual(collection.receiptGeneration, 2, "A new drop still confirms when total count returns to the same value")
  }

  @MainActor
  func testSevenProviderFilesProduceOneReceiptAndFailedSaveProducesNone() async throws {
    let collection = store()
    let providers = try (1...7).map { number in
      NSItemProvider(item: try source("\(number).txt") as NSURL, typeIdentifier: "public.file-url")
    }
    await CollectionImporter.collect(providers, into: collection)
    XCTAssertEqual(collection.items.count, 7)
    XCTAssertEqual(collection.receiptGeneration, 1)
    let broken = CollectionStore(directory: root.appendingPathComponent("broken"), securityScoped: false) { _, _ in
      throw CocoaError(.fileWriteOutOfSpace)
    }
    await CollectionImporter.collect(providers, into: broken)
    XCTAssertTrue(broken.items.isEmpty)
    XCTAssertEqual(broken.receiptGeneration, 0)
    XCTAssertEqual(broken.importingCount, 0)
    XCTAssertNotNil(broken.lastError)
  }

  func testApprovedCollectionSoundIsIncludedInBuiltApp() throws {
    let url = try XCTUnwrap(Bundle.main.url(forResource: "Collect", withExtension: "wav"))
    let sound = try XCTUnwrap(NSSound(contentsOf: url, byReference: false))
    XCTAssertEqual(sound.duration, 0.38, accuracy: 0.002)
  }

  @MainActor
  func testOverlappingDropsOfSameFileOnlyConfirmOneActualInsertion() async throws {
    let collection = store()
    let url = try source()
    let requested = expectation(description: "Both drops start before either file arrives")
    requested.expectedFulfillmentCount = 2
    let gate = DispatchSemaphore(value: 0)
    func provider() -> NSItemProvider {
      let provider = NSItemProvider()
      provider.registerDataRepresentation(forTypeIdentifier: "public.file-url", visibility: .all) { completion in
        requested.fulfill()
        DispatchQueue.global().async {
          _ = gate.wait(timeout: .now() + 3)
          completion(url.dataRepresentation, nil)
        }
        return nil
      }
      return provider
    }
    let first = Task { await CollectionImporter.collect([provider()], into: collection) }
    let second = Task { await CollectionImporter.collect([provider()], into: collection) }
    await fulfillment(of: [requested], timeout: 2)
    gate.signal()
    gate.signal()
    await first.value
    await second.value
    XCTAssertEqual(collection.items.count, 1)
    XCTAssertEqual(collection.receiptGeneration, 1, "The duplicate-only drop must not confirm another batch's insertion")
    XCTAssertEqual(collection.importingCount, 0)
  }

  func testSearchHitShowsWholeStackAndLastMemberBecomesOrdinaryCard() throws {
    let batch = UUID()
    let collection = store()
    let a = try collection.addFile(source("alpha.txt"), batch: batch)
    try collection.addFile(source("beta.txt"), batch: batch)
    try collection.addFile(source("gamma.txt"))
    collection.searchQuery = "beta"
    XCTAssertEqual(Set(collection.visibleItems.map(\.name)), ["alpha.txt", "beta.txt"])

    collection.searchQuery = ""
    try collection.remove(ids: [a])
    XCTAssertTrue(collection.visibleEntries.allSatisfy { if case .single = $0 { true } else { false } })
  }

  func testStackPinActsOnWholeGroupAndKeyboardTreatsStackAsOneStop() throws {
    let batch = UUID()
    let collection = store()
    let a = try collection.addFile(source("a.txt"), batch: batch)
    let b = try collection.addFile(source("b.txt"), batch: batch)
    let single = try collection.addFile(source("c.txt"))
    try collection.togglePin(a)
    try collection.togglePin(ids: [a, b])
    XCTAssertTrue(collection.items.filter { $0.batchID == batch }.allSatisfy(\.isPinned), "partly pinned group pins all")
    try collection.togglePin(ids: [a, b])
    XCTAssertTrue(collection.items.allSatisfy { !$0.isPinned })

    collection.moveSelection(by: 1)
    XCTAssertEqual(collection.selectedIDs, [single])
    collection.moveSelection(by: 1)
    XCTAssertEqual(collection.selectedIDs, [a, b])
  }

}

private final class CollectionImageURLProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "clipio.invalid" }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let path = request.url!.lastPathComponent
    var headers = ["Content-Type": path == "not-image" ? "application/octet-stream" : "image/png"]
    if path == "oversized" { headers["Content-Length"] = "1000000000" }
    if path == "valid" { headers["Content-Length"] = "4" }
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    // CFNetwork can sniff image responses before forwarding headers. Supply a
    // prefix while leaving the stream unfinished to verify early cancellation.
    if path == "chunked" || path == "oversized" {
      client?.urlProtocol(self, didLoad: Data(repeating: 0, count: 32768))
    }
    if path == "valid" {
      client?.urlProtocol(self, didLoad: Data([1, 2, 3, 4]))
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {}
}
