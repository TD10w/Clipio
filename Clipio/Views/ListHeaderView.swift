import Defaults
import KeyboardShortcuts
import SwiftUI

struct ListHeaderView: View {
  @FocusState.Binding var searchFocused: Bool
  @Binding var searchQuery: String

  @Environment(AppState.self) private var appState
  @Environment(\.scenePhase) private var scenePhase

  @Default(.showTitle) private var showTitle

  var body: some View {
    HStack(spacing: 12) {
      if showTitle {
        Text("Clipio")
          .font(.system(size: FloatingGlassStyle.wordmarkFontSize, weight: .semibold))
          .foregroundStyle(.primary.opacity(0.92))
          .padding(.leading, 2)
      }

      Button {
        appState.switchShelf(to: appState.shelfMode.other)
      } label: {
        Image(systemName: appState.shelfMode.symbol)
          .font(.system(size: 13, weight: .medium))
          .frame(width: FloatingGlassStyle.toolbarControlSize, height: FloatingGlassStyle.toolbarControlSize)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("switch-shelf")
      .accessibilityLabel(Text(appState.shelfMode == .clipboard ? "collection_switch_to_collection" : "collection_switch_to_clipboard"))
      .help(Text("collection_switch_hint"))

      if appState.shelfMode == .clipboard {
        Picker("star_filter", selection: Binding(
          get: { appState.history.filter },
          set: { appState.history.setFilter($0) }
        )) {
          Text("star_all").tag(ClipboardFilter.all)
          Text("star_favorites").tag(ClipboardFilter.favorites)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("clipboard-filter")
      }

      SearchFieldView(placeholder: "search_placeholder", query: $searchQuery)
        .id(appState.shelfMode)
        .focused($searchFocused)
        .frame(maxWidth: .infinity)
        .onChange(of: scenePhase) {
          if scenePhase == .background && !searchQuery.isEmpty {
            searchQuery = ""
          }
        }
        // Only reliable way to disable the cursor. allowsHitTesting() does not work
        .offset(y: appState.searchVisible ? 0 : -Popup.itemHeight)
    }
  }
}
