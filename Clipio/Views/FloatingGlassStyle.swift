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

  // Spectral palette from the original (2.6.1) shelf.
  static let cardTint = Color(red: 0.82, green: 0.94, blue: 1.0)
  static let rimTint = Color(red: 0.72, green: 0.95, blue: 1.0)
  static let spectralTint = Color(red: 1.0, green: 0.72, blue: 0.92)

  /// Transparency slider: 0 = clearest liquid glass (the 2.6.1 look; background text
  /// stays readable through it), 1 = fully frosted (background reduced to soft colour so
  /// Clipio's own text never collides with it). Same rule in light and dark appearance.
  static let defaultGlassOpacity = 0.5

  /// Opacity of the behind-window blur layered on the clear glass.
  static func blurOpacity(_ position: Double) -> Double {
    min(max(position, 0), 1)
  }

  /// Light/dark wash over the blur. Light keeps 2.6.1's white body; both deepen toward
  /// the frosted end so text contrast keeps rising.
  static func tintOpacity(_ position: Double, dark: Bool) -> Double {
    let v = min(max(position, 0), 1)
    return dark ? 0.30 * v : 0.20 + 0.30 * v
  }

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
