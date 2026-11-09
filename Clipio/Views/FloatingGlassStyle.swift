import SwiftUI

enum FloatingGlassStyle {
  static let cardWidth: CGFloat = 138
  static let cardHeight: CGFloat = 150
  static let cardRadius: CGFloat = 26
  static let cardSpacing: CGFloat = 12
  static let trayRadius: CGFloat = 30
  static let searchHeight: CGFloat = 32
  static let toolbarControlSize: CGFloat = 28
  static let textCardTopPadding: CGFloat = 32
  static let cardBodyFontSize: CGFloat = 13
  static let metadataFontSize: CGFloat = 11.5
  static let wordmarkFontSize: CGFloat = 17

  // Pop-out "unfold" animation tunables — one-line changes to dial in the feel.
  // The shelf scales up from this seed (anchored top-center) into full size. Because the
  // whole view scales, the 30pt tray radius scales with it, giving the chip its pill shape.
  static let seedScaleX: CGFloat = 0.12
  static let seedScaleY: CGFloat = 0.10
  static let unfoldResponse: Double = 0.34
  static let unfoldDamping: Double = 0.78
  static let contentFadeDelay: Double = 0.16
  static let contentFadeDuration: Double = 0.16
}
