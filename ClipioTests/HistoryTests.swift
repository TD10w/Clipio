import XCTest
import Defaults
import SwiftUI
import Logging
@testable import Clipio

private final class LogRecorder {
  var messages: [String] = []
}

private struct RecordingLogHandler: LogHandler {
  let recorder: LogRecorder
  var logLevel: Logger.Level = .trace
  var metadata: Logger.Metadata = [:]

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { metadata[key] }
    set { metadata[key] = newValue }
  }

  func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    recorder.messages.append(message.description)
  }
}

@MainActor
class HistoryTests: XCTestCase {
  let savedSize = Defaults[.size]
  let savedSortBy = Defaults[.sortBy]
  let history = History.shared

  override func setUp() {
    super.setUp()
    history.clearAll()
    Defaults[.size] = 10
    Defaults[.sortBy] = .firstCopiedAt
  }

  override func tearDown() {
    super.tearDown()
    Defaults[.size] = savedSize
    Defaults[.sortBy] = savedSortBy
  }

  func testDefaultIsEmpty() {
    XCTAssertEqual(history.items, [])
  }

  func testAdding() {
    let first = history.add(historyItem("foo"))
    let second = history.add(historyItem("bar"))
    XCTAssertEqual(history.items, [second, first])
  }

  func testHistoryLogsNeverContainClipboardTitle() {
    let marker = "private-clipboard-marker-\(UUID().uuidString)"
    let recorder = LogRecorder()
    var logger = Logger(label: "com.clipio.tests") { _ in
      RecordingLogHandler(recorder: recorder)
    }
    logger.logLevel = .trace
    let isolatedHistory = History(logger: logger)

    isolatedHistory.add(historyItem(marker))
    isolatedHistory.add(historyItem(marker))

    XCTAssertFalse(recorder.messages.contains(where: { $0.contains(marker) }))
  }

  func testAddingSame() {
    let first = historyItem("foo")
    first.firstCopiedAt = .distantPast
    first.lastCopiedAt = .distantPast
    first.title = "xyz"
    first.application = "iTerm.app"
    let firstDecorator = history.add(first)
    first.pin = "f"

    let secondDecorator = history.add(historyItem("bar"))

    let third = historyItem("foo")
    third.application = "Xcode.app"
    let thirdDecorator = history.add(third)

    XCTAssertEqual(history.items.map { $0.item.title }, ["xyz", secondDecorator.item.title])
    XCTAssertEqual(history.items.first?.item.text, "foo")
    XCTAssertTrue(thirdDecorator.item.lastCopiedAt > thirdDecorator.item.firstCopiedAt)
    // TODO: This works in reality but fails in tests?!
    // XCTAssertEqual(history.items[0].item.numberOfCopies, 2)
    XCTAssertEqual(history.items[0].item.pin, "f")
    XCTAssertEqual(history.items[0].item.title, "xyz")
    XCTAssertEqual(history.items[0].item.application, "iTerm.app")
  }

  func testAddingItemThatIsSupersededByExisting() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.rtf.rawValue,
        value: "two".data(using: .utf8)!
      )
    ]
    let firstItem = HistoryItem()
    Storage.shared.context.insert(firstItem)
    firstItem.application = "Maccy.app"
    firstItem.contents = firstContents
    firstItem.title = firstItem.generateTitle()
    history.add(firstItem)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      )
    ]
    let secondItem = HistoryItem()
    Storage.shared.context.insert(secondItem)
    secondItem.application = "Maccy.app"
    secondItem.contents = secondContents
    secondItem.title = secondItem.generateTitle()
    let second = history.add(secondItem)

    XCTAssertEqual(history.items, [second])
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  func testAddingItemWithDifferentModifiedType() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: "1".data(using: .utf8)!
      )
    ]
    let firstItem = HistoryItem()
    Storage.shared.context.insert(firstItem)
    firstItem.contents = firstContents
    history.add(firstItem)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)!
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.modified.rawValue,
        value: "2".data(using: .utf8)!
      )
    ]
    let secondItem = HistoryItem()
    Storage.shared.context.insert(secondItem)
    secondItem.contents = secondContents
    let second = history.add(secondItem)

    XCTAssertEqual(history.items, [second])
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  func testAddingItemFromMaccy() {
    let firstContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)
      )
    ]
    let first = HistoryItem()
    Storage.shared.context.insert(first)
    first.application = "Xcode.app"
    first.contents = firstContents
    history.add(first)

    let secondContents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: "one".data(using: .utf8)
      ),
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.fromMaccy.rawValue,
        value: "".data(using: .utf8)
      )
    ]
    let second = HistoryItem()
    Storage.shared.context.insert(second)
    second.application = "Maccy.app"
    second.contents = secondContents
    let secondDecorator = history.add(second)

    XCTAssertEqual(history.items, [secondDecorator])
    XCTAssertEqual(history.items[0].item.application, "Xcode.app")
    XCTAssertEqual(Set(history.items[0].item.contents), Set(firstContents))
  }

  func testModifiedAfterCopying() {
    history.add(historyItem("foo"))

    let modifiedItem = historyItem("bar")
    modifiedItem.contents.append(HistoryItemContent(
      type: NSPasteboard.PasteboardType.modified.rawValue,
      value: String(Clipboard.shared.changeCount).data(using: .utf8)
    ))
    let modifiedItemDecorator = history.add(modifiedItem)

    XCTAssertEqual(history.items, [modifiedItemDecorator])
    XCTAssertEqual(history.items[0].text, "bar")
  }

  func testClearingUnpinned() {
    let pinned = history.add(historyItem("foo"))
    pinned.togglePin()
    history.add(historyItem("bar"))
    history.clear()
    XCTAssertEqual(history.items, [pinned])
  }

  func testClearingAll() {
    history.add(historyItem("foo"))
    history.clear()
    XCTAssertEqual(history.items, [])
  }

  func testMaxSize() {
    var items: [HistoryItemDecorator] = []
    for index in 0...10 {
      items.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.items.count, 10)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertFalse(history.items.contains(items[0]))
  }

  func testNewestItemBecomesScrollTargetAtMaxSize() {
    for index in 0..<10 {
      history.add(historyItem(String(index)))
    }
    AppState.shared.navigator.scrollTarget = nil

    let newest = history.add(historyItem("10"))

    XCTAssertEqual(history.items.count, 10)
    XCTAssertEqual(history.items.first, newest)
    XCTAssertEqual(AppState.shared.navigator.scrollTarget, newest.id)
  }

  func testMaxSizeIgnoresPinned() {
    var items: [HistoryItemDecorator] = []

    let item = history.add(historyItem("0"))
    items.append(item)
    item.togglePin()

    for index in 1...11 {
      items.append(history.add(historyItem(String(index))))
    }

    XCTAssertEqual(history.items.count, 11)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertTrue(history.items.contains(items[0]))
    XCTAssertFalse(history.items.contains(items[1]))
  }

  func testMaxSizeIsChanged() {
    var items: [HistoryItemDecorator] = []
    for index in 0...10 {
      items.append(history.add(historyItem(String(index))))
    }
    Defaults[.size] = 5
    history.add(historyItem("11"))

    XCTAssertEqual(history.items.count, 5)
    XCTAssertTrue(history.items.contains(items[10]))
    XCTAssertFalse(history.items.contains(items[5]))
  }

  func testRemoving() {
    let foo = history.add(historyItem("foo"))
    let bar = history.add(historyItem("bar"))
    history.delete(foo)
    XCTAssertEqual(history.items, [bar])
  }

  func testFavoritesFilterIncludesLegacyPinsAndPreservesQuery() async throws {
    defer { history.setFilter(.all); history.searchQuery = "" }
    let oldMode = Defaults[.searchMode]
    Defaults[.searchMode] = .exact
    defer { Defaults[.searchMode] = oldMode }
    let favorite = history.add(historyItem("asset saved"))
    favorite.togglePin()
    let ordinary = history.add(historyItem("asset recent"))
    history.searchQuery = "asset"
    try await Task.sleep(for: .milliseconds(300))
    history.setFilter(.favorites)
    XCTAssertEqual(history.items.map { $0.item.text }, ["asset saved"])
    XCTAssertEqual(history.searchQuery, "asset")
    history.setFilter(.all)
    XCTAssertTrue(history.items.contains { $0.item.text == ordinary.item.text })
    XCTAssertEqual(history.searchQuery, "asset")
  }

  func testExternalCopyResetsOnlyNextOpeningAndOwnCopyDoesNot() {
    defer { history.setFilter(.all); history.searchQuery = "" }
    let saved = history.add(historyItem("saved"))
    saved.togglePin()
    history.setFilter(.favorites)
    history.searchQuery = "saved"
    history.add(historyItem("new external"))
    XCTAssertEqual(history.filter, .favorites)
    XCTAssertEqual(history.items, [saved])
    history.prepareForOpening()
    XCTAssertEqual(history.filter, .all)
    XCTAssertEqual(history.searchQuery, "")
    history.setFilter(.favorites)
    let own = historyItem("saved")
    own.contents.append(HistoryItemContent(type: NSPasteboard.PasteboardType.fromMaccy.rawValue, value: Data()))
    history.add(own)
    history.prepareForOpening()
    XCTAssertEqual(history.filter, .favorites)
    history.add(historyItem("another external"))
    history.setFilter(.favorites)
    history.prepareForOpening()
    XCTAssertEqual(history.filter, .favorites, "A later explicit filter choice wins")
  }

  func testStarAndUnstarDoNotNavigateAndLastUnstarLeavesEmptyFavorites() {
    defer { history.setFilter(.all) }
    let saved = history.add(historyItem("saved"))
    history.setFilter(.all)
    history.togglePin(saved)
    history.prepareForOpening()
    XCTAssertEqual(history.filter, .all)
    history.setFilter(.favorites)
    history.togglePin(saved)
    XCTAssertEqual(history.filter, .favorites)
    XCTAssertTrue(history.items.isEmpty)
  }

  func testFavoriteNamePreservesContentAndSurvivesDuplicateAndReload() async throws {
    defer { history.setFilter(.all); history.searchQuery = "" }
    let saved = history.add(historyItem("https://example.com/portfolio"))
    history.togglePin(saved)
    history.setFavoriteName(saved, name: "  Personal website  ")
    XCTAssertEqual(saved.title, "Personal website")
    XCTAssertEqual(saved.item.text, "https://example.com/portfolio")
    let duplicate = history.add(historyItem("https://example.com/portfolio"))
    XCTAssertTrue(duplicate.isPinned)
    XCTAssertEqual(duplicate.item.favoriteName, "Personal website")
    try await history.load()
    XCTAssertEqual(history.items.first?.title, "Personal website")
    let search = Search()
    XCTAssertFalse(search.search(string: "Personal", within: history.all).isEmpty)
    XCTAssertFalse(search.search(string: "example.com", within: history.all).isEmpty)
    history.setFavoriteName(history.items.first!, name: "")
    XCTAssertNil(history.items.first?.item.favoriteName)
    XCTAssertEqual(history.items.first?.item.text, "https://example.com/portfolio")
  }

  func testFavoriteImageBytesSurviveClearAndReload() async throws {
    defer { history.setFilter(.all) }
    let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    let model = HistoryItem(contents: [HistoryItemContent(type: "public.png", value: png)])
    let saved = history.add(model)
    history.togglePin(saved)
    history.setFavoriteName(saved, name: "Avatar")
    history.add(historyItem("ordinary"))
    history.clear()
    try await history.load()
    XCTAssertEqual(history.items.count, 1)
    XCTAssertEqual(history.items.first?.title, "Avatar")
    XCTAssertEqual(history.items.first?.item.imageData, png)
  }

  func testFullClearAlwaysRequiresExplicitConfirmation() {
    var actions = 0
    let item = FooterItem(title: "clear_all", confirmation: .init(message: "m", comment: "c", confirm: "yes", cancel: "no"),
      suppressConfirmation: .constant(true)) { actions += 1 }
    item.requiresConfirmation = true
    item.requestAction()
    XCTAssertTrue(item.showConfirmation)
    XCTAssertEqual(actions, 0)
    XCTAssertTrue(Footer().items[1].requiresConfirmation)
  }

  func testFavoriteRegexSearchMatchesAliasAndOriginalIndependently() {
    let oldMode = Defaults[.searchMode]
    Defaults[.searchMode] = .regexp
    defer { Defaults[.searchMode] = oldMode }
    let item = history.add(historyItem("https://example.com"))
    history.togglePin(item)
    history.setFavoriteName(item, name: "Personal website")
    let search = Search()
    XCTAssertEqual(search.search(string: "^https://", within: [item]).count, 1)
    XCTAssertEqual(search.search(string: "^Personal website$", within: [item]).count, 1)
  }

  func testRenameCannotLeaveAHiddenFavoriteSelected() async throws {
    let oldMode = Defaults[.searchMode]
    Defaults[.searchMode] = .exact
    defer { Defaults[.searchMode] = oldMode; history.setFilter(.all); history.searchQuery = "" }
    let item = history.add(historyItem("content"))
    history.togglePin(item)
    history.setFavoriteName(item, name: "OldAliasX")
    history.setFilter(.favorites)
    history.searchQuery = "OldAliasX"
    try await Task.sleep(for: .milliseconds(300))
    let selected = try XCTUnwrap(history.items.first)
    AppState.shared.navigator.select(item: selected)
    history.setFavoriteName(selected, name: "NewName")
    XCTAssertTrue(history.items.isEmpty)
    XCTAssertTrue(AppState.shared.navigator.selection.isEmpty)
  }

  func testEnteringClipboardFromOpenCollectionAppliesPendingCopyIntent() {
    defer { history.setFilter(.all); history.searchQuery = ""; AppState.shared.switchShelf(to: .clipboard) }
    let item = history.add(historyItem("saved"))
    history.togglePin(item)
    history.setFilter(.favorites)
    history.searchQuery = "saved"
    AppState.shared.switchShelf(to: .collection)
    history.add(historyItem("external"))
    AppState.shared.switchShelf(to: .clipboard)
    XCTAssertEqual(history.filter, .all)
    XCTAssertEqual(history.searchQuery, "")
  }

  private func historyItem(_ value: String) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.numberOfCopies = 1
    item.title = item.generateTitle()

    return item
  }
}
