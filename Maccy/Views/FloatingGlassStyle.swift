import SwiftUI

enum FloatingGlassStyle {
  static let cardWidth: CGFloat = 138
  static let cardHeight: CGFloat = 150
  static let cardRadius: CGFloat = 26
  static let cardSpacing: CGFloat = 12
  static let trayScrimOpacity = 0.06
  static let cardFillOpacity = 0.055
  static let cardTintOpacity = 0.10
  static let trayRadius: CGFloat = 30
  static let searchHeight: CGFloat = 32
  static let toolbarControlSize: CGFloat = 28
  static let textCardTopPadding: CGFloat = 32

  static let cardTint = Color(red: 0.82, green: 0.94, blue: 1.0)
  static let rimTint = Color(red: 0.72, green: 0.95, blue: 1.0)
  static let spectralTint = Color(red: 1.0, green: 0.72, blue: 0.92)

  // Keep the interactive shelf at identity scale. A visual scale transform makes the
  // rendered cards diverge from AppKit's unscaled tracking areas, so hover/click targets
  // drift farther out of alignment toward the right edge. Opening still uses the content
  // fade below; geometry must remain fixed for pointer accuracy.
  static let seedScaleX: CGFloat = 1
  static let seedScaleY: CGFloat = 1
  static let unfoldResponse: Double = 0.34
  static let unfoldDamping: Double = 0.78
  static let contentFadeDelay: Double = 0.16
  static let contentFadeDuration: Double = 0.16
}
