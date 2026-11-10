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
struct ShelfGlassSurface: ViewModifier {
  let radius: CGFloat
  @Default(.shelfGlassAppearance) private var appearance
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    if reduceTransparency {
      content.background(Color(nsColor: .windowBackgroundColor), in: shape)
    } else if #available(macOS 26.0, *) {
      content
        .background { tint(shape) }
        .glassEffect(glass, in: shape)
    } else {
      content.background(VisualEffectView().clipShape(shape))
    }
  }

  @available(macOS 26.0, *)
  private var glass: Glass {
    switch appearance {
    case .system: return .regular
    case .classic, .clear, .crystal: return .clear
    case .aurora: return .regular.tint(FloatingGlassStyle.auroraTint.opacity(colorScheme == .dark ? 0.22 : 0.16))
    }
  }

  @ViewBuilder
  private func tint(_ shape: RoundedRectangle) -> some View {
    switch appearance {
    case .classic:
      // In light mode clear glass has no body; a white scrim gives the shelf mass.
      if colorScheme == .light { shape.fill(Color.white.opacity(0.55)) }
    case .crystal:
      shape.fill(colorScheme == .light ? Color.white.opacity(0.22) : Color.black.opacity(0.10))
    case .aurora:
      shape.fill(
        LinearGradient(
          colors: [
            FloatingGlassStyle.rimTint.opacity(0.14),
            FloatingGlassStyle.auroraTint.opacity(0.08),
            FloatingGlassStyle.spectralTint.opacity(0.12)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    case .system, .clear:
      EmptyView()
    }
  }
}

/// Perimeter of the tray / entry pill. Spectral styles use the original cyan→pink lens rim.
struct ShelfGlassRim: View {
  let radius: CGFloat
  @Default(.shelfGlassAppearance) private var appearance

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    Group {
      if appearance.isSpectral {
        shape.strokeBorder(
          LinearGradient(
            colors: [
              Color.primary.opacity(appearance == .aurora ? 0.16 : 0.22),
              FloatingGlassStyle.rimTint.opacity(0.26),
              FloatingGlassStyle.spectralTint.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
      } else {
        shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
      }
    }
    .allowsHitTesting(false)
  }
}
