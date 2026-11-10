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

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    if reduceTransparency {
      content.background(Color(nsColor: .windowBackgroundColor), in: shape)
    } else if #available(macOS 26.0, *) {
      content.glassEffect(appearance == .clear ? .clear : .regular, in: shape)
    } else {
      content.background(VisualEffectView().clipShape(shape))
    }
  }
}
