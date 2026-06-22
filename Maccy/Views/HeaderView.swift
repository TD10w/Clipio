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

        HeaderClearButton(
          clearItem: appState.footer.items[0],
          clearAllItem: appState.footer.items[1]
        )
        .padding(.trailing, 5)

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

private struct HeaderClearButton: View {
  @Bindable var clearItem: FooterItem
  @Bindable var clearAllItem: FooterItem

  @Environment(ModifierFlags.self) private var modifierFlags

  private var isClearAll: Bool {
    modifierFlags.flags.contains(.shift)
  }

  var body: some View {
    ToolbarButton {
      requestClear(isClearAll ? clearAllItem : clearItem)
    } label: {
      Image(systemName: isClearAll ? "trash.slash" : "trash")
        .font(.system(size: 13, weight: .medium))
    }
    .modifier(HeaderGlassControl())
    .accessibilityIdentifier("clear-history")
    .accessibilityLabel(Text(isClearAll ? "clear_all" : "clear"))
    .help(Text(isClearAll ? "clear_all_tooltip" : "clear_tooltip"))
    .confirmationDialog(
      clearItem.confirmation?.message ?? "clear_alert_message",
      isPresented: $clearItem.showConfirmation
    ) {
      clearConfirmationButtons(for: clearItem)
    }
    .dialogSuppressionToggle(isSuppressed: clearItem.suppressConfirmation ?? .constant(false))
    .confirmationDialog(
      clearAllItem.confirmation?.message ?? "clear_alert_message",
      isPresented: $clearAllItem.showConfirmation
    ) {
      clearConfirmationButtons(for: clearAllItem)
    }
    .dialogSuppressionToggle(isSuppressed: clearAllItem.suppressConfirmation ?? .constant(false))
  }

  @ViewBuilder
  private func clearConfirmationButtons(for item: FooterItem) -> some View {
    if let confirmation = item.confirmation {
      Text(confirmation.comment)
      Button(confirmation.confirm, role: .destructive) {
        item.action()
      }
      Button(confirmation.cancel, role: .cancel) {}
    }
  }

  private func requestClear(_ item: FooterItem) {
    if item.suppressConfirmation?.wrappedValue == true {
      item.action()
    } else {
      item.showConfirmation = true
    }
  }
}

private struct HeaderGlassControl: ViewModifier {
  func body(content: Content) -> some View {
    let size = FloatingGlassStyle.toolbarControlSize

    // Solid material circles (not glass) — lighter to render and legible in both modes.
    content
      .frame(width: size, height: size)
      .background(.regularMaterial, in: Circle())
      .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8))
  }
}
