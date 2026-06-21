import Defaults
import SwiftUI

struct HeaderView: View {
  @State private var appState = AppState.shared

  let controller: SlideoutController
  @FocusState.Binding var searchFocused: Bool

  var previewPlacement: SlideoutPlacement {
    return controller.placement
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      HStack(alignment: .center, spacing: 0) {
        ListHeaderView(
          searchFocused: $searchFocused,
          searchQuery: $appState.history.searchQuery
        )
        .padding(.horizontal, Popup.horizontalPadding)

        ToolbarButton {
          Task { @MainActor in
            AppState.shared.openPreferences()
          }
        } label: {
          Image(systemName: "gearshape")
            .font(.system(size: 13, weight: .medium))
        }
        .modifier(HeaderGlassControl())

        ToolbarButton {
          AppState.shared.quit()
        } label: {
          Image(systemName: "power")
            .font(.system(size: 13, weight: .medium))
        }
        .modifier(HeaderGlassControl())
        .padding(.leading, 5)
        .padding(.trailing, Popup.horizontalPadding)
      }
      .opacity(appState.searchVisible ? 1 : 0)
      .layoutPriority(1)
    }
    .padding(.top, 8)
    .padding(.horizontal, 12)
    .animation(.default.speed(3), value: appState.navigator.leadSelection)
    .background(.clear)
    .frame(maxHeight: !appState.searchVisible ? 0 : nil, alignment: .top)
    .readHeight(appState, into: \.popup.headerHeight)
  }
}

private struct HeaderGlassControl: ViewModifier {
  func body(content: Content) -> some View {
    let size = FloatingGlassStyle.toolbarControlSize

    if #available(macOS 26.0, *) {
      content
        .frame(width: size, height: size)
        .glassEffect(.regular.interactive(), in: .circle)
    } else {
      content
        .frame(width: size, height: size)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.26), lineWidth: 0.8))
    }
  }
}
