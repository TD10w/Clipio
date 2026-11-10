import SwiftUI
import Defaults

struct VisualEffectView: NSViewRepresentable {
  let visualEffectView = NSVisualEffectView()

  var material: NSVisualEffectView.Material = .popover
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    return visualEffectView
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}

@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
  let glassEffectView = NSGlassEffectView()

  var style: NSGlassEffectView.Style = .regular

  func makeNSView(context: Context) -> NSGlassEffectView {
    return glassEffectView
  }

  func updateNSView(_ view: NSGlassEffectView, context: Context) {
    glassEffectView.style = style
  }
}

#Preview {
  VisualEffectView(
    material: .popover,
    blendingMode: .behindWindow
  )
}

/// Native glass retains system appearance/accessibility behavior. Never adjust the
/// whole window's alpha: that would also fade text, icons and drop affordances.
/// Opacity comes from a scrim over clear glass, set by the transparency slider.
struct ShelfGlassSurface: ViewModifier {
  let radius: CGFloat
  @Default(.shelfGlassOpacity) private var opacity
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    let dark = colorScheme == .dark
    let scrim = shape.fill((dark ? Color.black : Color.white)
      .opacity(FloatingGlassStyle.scrimOpacity(opacity, dark: dark)))
    if reduceTransparency {
      content.background(Color(nsColor: .windowBackgroundColor), in: shape)
    } else if #available(macOS 26.0, *) {
      content
        .background { scrim }
        .glassEffect(.clear, in: shape)
    } else {
      content.background { ZStack { VisualEffectView().clipShape(shape); scrim } }
    }
  }
}

/// Perimeter of the tray / entry pill: the original cyan→pink lens rim.
struct ShelfGlassRim: View {
  let radius: CGFloat

  var body: some View {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
      .strokeBorder(
        LinearGradient(
          colors: [
            Color.primary.opacity(0.22),
            FloatingGlassStyle.rimTint.opacity(0.26),
            FloatingGlassStyle.spectralTint.opacity(0.16)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      )
      .allowsHitTesting(false)
  }
}
