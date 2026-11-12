import XCTest
import AppKit
import SwiftUI
@testable import Clipio

final class FloatingGlassStyleTests: XCTestCase {
  func testTestRunUsesIsolatedRuntimeEnvironment() {
    XCTAssertTrue(RuntimeEnvironment.isTesting)
  }

  func testUITestArgumentsUseIsolatedFullAppMode() {
    let environment = RuntimeEnvironment(
      arguments: ["Clipio", "enable-testing", "enable-ui-testing"]
    )

    XCTAssertTrue(environment.isUITesting)
    XCTAssertFalse(environment.isUnitTesting)
    XCTAssertTrue(environment.isTesting)
    XCTAssertTrue(environment.usesInMemoryStorage)
    XCTAssertFalse(environment.skipsApplicationStartup)
  }

  func testUnitTestArgumentsUseIsolatedHeadlessMode() {
    let environment = RuntimeEnvironment(arguments: ["Clipio", "enable-testing"])

    XCTAssertFalse(environment.isUITesting)
    XCTAssertTrue(environment.isUnitTesting)
    XCTAssertTrue(environment.isTesting)
    XCTAssertTrue(environment.usesInMemoryStorage)
    XCTAssertTrue(environment.skipsApplicationStartup)
  }

  func testNativeGlassDirectionPreservesShelfGeometry() {
    XCTAssertEqual(FloatingGlassStyle.cardWidth, 138)
    XCTAssertEqual(FloatingGlassStyle.cardHeight, 150)
    XCTAssertEqual(FloatingGlassStyle.cardRadius, 26)
    XCTAssertEqual(FloatingGlassStyle.cardSpacing, 12)
    XCTAssertEqual(FloatingGlassStyle.trayRadius, 30)
    XCTAssertEqual(FloatingGlassStyle.searchHeight, 32)
    XCTAssertEqual(FloatingGlassStyle.toolbarControlSize, 28)
    XCTAssertEqual(FloatingGlassStyle.textCardTopPadding, 32)
  }

  func testReopenInvalidatesPendingCloseCompletion() {
    var state = FloatingPanelAnimationState()
    let closeToken = state.beginClose()

    state.didOpen()

    XCTAssertFalse(state.canFinishClose(closeToken))
  }
}

final class MenuIconPresentationTests: XCTestCase {
  func testImageIconsKeepImageLeftStatusItemPosition() {
    for icon in [MenuIcon.maccy, .clipboard, .paperclip] {
      XCTAssertEqual(icon.statusItemImagePosition, .imageLeft)
    }
  }

  func testTextGlyphIconDoesNotReserveImageSpace() {
    XCTAssertEqual(MenuIcon.scissors.statusItemImagePosition, .noImage)
  }
}

@MainActor
final class ShelfBehaviorTests: XCTestCase {
  func testStarClickBesideWideImageDoesNotSelectOrDragCard() async throws {
    let history = History.shared
    let first = history.add(HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("first hit-test card".utf8))]))
    let second = history.add(HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("wide hit-test card".utf8))]))
    defer { history.delete(first); history.delete(second) }
    first.thumbnailImage = NSImage(size: NSSize(width: 200, height: 600))
    second.thumbnailImage = NSImage(size: NSSize(width: 2400, height: 400))
    var cardSelections = 0
    let width = CardItemView.cardWidth * 2 + FloatingGlassStyle.cardSpacing
    let height = CardItemView.cardHeight
    let host = StarHitHostingView(rootView: HStack(spacing: FloatingGlassStyle.cardSpacing) {
      CardItemView(item: first, isHovered: true) { cardSelections += 1 }
      CardItemView(item: second, isHovered: true) { cardSelections += 1 }
    }.frame(width: width, height: height))
    host.sizingOptions = []
    let panel = NSPanel(contentRect: NSRect(x: -12000, y: -12000, width: width, height: height),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    panel.alphaValue = 0.01
    panel.contentView = host
    panel.orderFront(nil)
    defer { panel.orderOut(nil); panel.close() }
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(150))
    func clickStar() throws {
      let point = NSPoint(x: CardItemView.cardWidth - 18, y: host.isFlipped ? 18 : height - 18)
      let location = host.convert(point, to: nil)
      for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
          context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
        panel.sendEvent(event)
      }
    }
    try clickStar()
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertTrue(first.isPinned, "A wide adjacent image must not steal the star hit")
    XCTAssertFalse(second.isPinned)
    XCTAssertEqual(cardSelections, 0, "Star clicks must not trigger the card selection/drag surface")
    try clickStar()
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertFalse(first.isPinned, "The same visible star target must also unpin")
    XCTAssertEqual(cardSelections, 0)
  }

  func testCollectionPinButtonReceivesClickAboveDragSurface() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("sample.txt")
    try Data("sample".utf8).write(to: file)
    let store = CollectionStore(directory: root.appendingPathComponent("collection"), securityScoped: false)
    let id = try store.addFile(file)
    try store.togglePin(id)
    let width = CardItemView.cardWidth + 28
    let height = CardItemView.cardHeight + 22
    let host = StarHitHostingView(rootView: CollectionShelfView(store: store).environment(AppState.shared))
    host.sizingOptions = []
    let panel = NSPanel(contentRect: NSRect(x: -12000, y: -12000, width: width, height: height),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isReleasedWhenClosed = false
    panel.alphaValue = 0.01
    panel.contentView = host
    panel.orderFront(nil)
    defer { panel.orderOut(nil); panel.close() }
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(150))
    let point = NSPoint(x: 14 + CardItemView.cardWidth - 18, y: host.isFlipped ? 28 : height - 28)
    let location = host.convert(point, to: nil)
    for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
      let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
        context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
      panel.sendEvent(event)
    }
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertFalse(store.items[0].isPinned)
  }

  func testThumbnailCacheRefusesUnboundedImageAndReleasesSmallImage() {
    let item = HistoryItemDecorator(HistoryItem())
    item.thumbnailImage = NSImage(size: NSSize(width: 5000, height: 5000))
    XCTAssertNil(item.thumbnailImage)
    item.thumbnailImage = NSImage(size: NSSize(width: 64, height: 64))
    XCTAssertNotNil(item.thumbnailImage)
    item.releaseThumbnailImage()
    XCTAssertNil(item.thumbnailImage)
  }

  func testImagePreviewUsesBoundedDecodedDimensions() throws {
    let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2400, pixelsHigh: 1200,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    let image = try XCTUnwrap(NSImage.downsampled(data: data, maxPixelSize: 240))
    let decoded = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    XCTAssertLessThanOrEqual(decoded.width, 240)
    XCTAssertLessThanOrEqual(decoded.height, 240)
  }

  func testFavoriteNameCannotChangeWhetherContentIsAColor() {
    let color = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("#FF0000".utf8))])
    color.title = "#FF0000"
    color.favoriteName = "Brand red"
    XCTAssertNotNil(CardItemView.contentColor(for: HistoryItemDecorator(color)))
    let text = HistoryItem(contents: [HistoryItemContent(type: "public.utf8-plain-text", value: Data("ordinary note".utf8))])
    text.title = "ordinary note"
    text.favoriteName = "#FF0000"
    XCTAssertNil(CardItemView.contentColor(for: HistoryItemDecorator(text)))
  }
  func testClipboardRemoveTargetsTheChosenCard() {
    final class RecordingHistory: History {
      var deletedItem: HistoryItemDecorator?
      override func delete(_ item: HistoryItemDecorator?) { deletedItem = item }
    }
    let history = RecordingHistory()
    let item = HistoryItemDecorator(HistoryItem())
    CardItemView.remove(item, from: history)
    XCTAssertIdentical(history.deletedItem, item)
  }
  func testCardPinActionUsesHistoryOwner() {
    final class RecordingHistory: History {
      var toggledItem: HistoryItemDecorator?

      override func togglePin(_ item: HistoryItemDecorator?) {
        toggledItem = item
      }
    }

    let history = RecordingHistory()
    let item = HistoryItemDecorator(HistoryItem())

    CardItemView.togglePin(item, in: history)

    XCTAssertIdentical(history.toggledItem, item)
  }

  func testPinnedItemsCanAppearAtTopOrBottom() {
    XCTAssertEqual(
      HistoryListView.orderedItems(pinned: [1, 2], unpinned: [3, 4], pinTo: .top),
      [1, 2, 3, 4]
    )
    XCTAssertEqual(
      HistoryListView.orderedItems(pinned: [1, 2], unpinned: [3, 4], pinTo: .bottom),
      [3, 4, 1, 2]
    )
  }

  func testShelfHoverSelectionUsesMeasuredCardFrames() {
    let first = UUID()
    let second = UUID()
    let frames = [
      first: CGRect(x: 14, y: 10, width: 138, height: 150),
      second: CGRect(x: 164, y: 10, width: 138, height: 150)
    ]

    XCTAssertEqual(
      HistoryListView.hoveredItemID(at: CGPoint(x: 151, y: 80), frames: frames),
      first
    )
    XCTAssertEqual(
      HistoryListView.hoveredItemID(at: CGPoint(x: 164, y: 80), frames: frames),
      second
    )
  }

  func testDisappearedCardCannotWinHoverAfterScrolling() {
    let old = UUID()
    let visible = UUID()
    let rect = CGRect(x: 14, y: 10, width: 138, height: 150)
    var frames = [old: rect, visible: rect]
    HistoryListView.removeFrame(for: old, from: &frames)
    XCTAssertEqual(HistoryListView.hoveredItemID(at: CGPoint(x: 30, y: 30), frames: frames), visible)
  }

  func testNavigationDoesNotEnterFooterWhenFooterIsNotRendered() {
    let history = History()
    let footer = Footer()
    footer.isRendered = false

    let item = HistoryItemDecorator(HistoryItem())
    history.items = [item]

    let navigator = NavigationManager(history: history, footer: footer)
    navigator.select(item: item)
    navigator.highlightNext()

    XCTAssertEqual(navigator.leadHistoryItem, item)
    XCTAssertNil(footer.selectedItem)
  }

  func testTransparencySliderGoesFromClearToFrostedInBothAppearances() {
    XCTAssertEqual(FloatingGlassStyle.defaultGlassOpacity, 0.5)
    XCTAssertEqual(FloatingGlassStyle.blurOpacity(0), 0)
    XCTAssertEqual(FloatingGlassStyle.blurOpacity(1), 1)
    for dark in [false, true] {
      XCTAssertLessThan(FloatingGlassStyle.tintOpacity(0.2, dark: dark), FloatingGlassStyle.tintOpacity(0.8, dark: dark))
    }
    XCTAssertLessThan(FloatingGlassStyle.blurOpacity(0.2), FloatingGlassStyle.blurOpacity(0.8))
  }
}

@MainActor
private final class StarHitHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
