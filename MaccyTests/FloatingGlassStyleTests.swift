import XCTest
@testable import Clipio

final class FloatingGlassStyleTests: XCTestCase {
  func testSelectedDirectionUsesCrystalLensMetrics() {
    XCTAssertEqual(FloatingGlassStyle.cardWidth, 138)
    XCTAssertEqual(FloatingGlassStyle.cardHeight, 150)
    XCTAssertEqual(FloatingGlassStyle.cardRadius, 26)
    XCTAssertEqual(FloatingGlassStyle.cardSpacing, 12)
    XCTAssertEqual(FloatingGlassStyle.trayScrimOpacity, 0.06)
    XCTAssertEqual(FloatingGlassStyle.cardFillOpacity, 0.055)
    XCTAssertEqual(FloatingGlassStyle.cardTintOpacity, 0.10)
    XCTAssertEqual(FloatingGlassStyle.trayRadius, 30)
    XCTAssertEqual(FloatingGlassStyle.searchHeight, 32)
    XCTAssertEqual(FloatingGlassStyle.toolbarControlSize, 28)
    XCTAssertEqual(FloatingGlassStyle.textCardTopPadding, 32)
  }
}

@MainActor
final class ShelfBehaviorTests: XCTestCase {
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
}
