import AppKit
import KeyboardShortcuts
import XCTest
@testable import Clipio

final class CollectionTests: XCTestCase {
  private var root: URL!
  private var directory: URL { root.appendingPathComponent("collection") }

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
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
    try collection.finishExport(export, accepted: false)
    XCTAssertEqual(store().items.count, 2)
  }

  func testAcceptedExportRemovesOnlyExportedUnpinnedItems() throws {
    let collection = store()
    let ordinary = try collection.addFile(source())
    let pinned = try collection.addFile(source("pinned.txt"))
    let untouched = try collection.addFile(source("untouched.txt"))
    try collection.togglePin(pinned)
    let export = try collection.prepareExport(ids: [ordinary, pinned])
    try collection.finishExport(export, accepted: true)
    XCTAssertEqual(Set(store().items.map(\.id)), [pinned, untouched])
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
    try collection.finishExport(export, accepted: true)
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
    let unsupported = NSItemProvider(item: "plain text" as NSString, typeIdentifier: "public.utf8-plain-text")
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

}
