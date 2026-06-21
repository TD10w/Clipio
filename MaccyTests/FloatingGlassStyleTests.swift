import XCTest
@testable import Clipio

final class FloatingGlassStyleTests: XCTestCase {
  func testSelectedDirectionUsesFloatingTileMetrics() {
    XCTAssertEqual(FloatingGlassStyle.cardWidth, 138)
    XCTAssertEqual(FloatingGlassStyle.cardHeight, 150)
    XCTAssertEqual(FloatingGlassStyle.cardRadius, 22)
    XCTAssertEqual(FloatingGlassStyle.cardSpacing, 12)
    XCTAssertEqual(FloatingGlassStyle.trayScrimOpacity, 0.18)
    XCTAssertEqual(FloatingGlassStyle.trayRadius, 28)
    XCTAssertEqual(FloatingGlassStyle.searchHeight, 32)
    XCTAssertEqual(FloatingGlassStyle.toolbarControlSize, 28)
    XCTAssertEqual(FloatingGlassStyle.textCardTopPadding, 32)
  }
}
