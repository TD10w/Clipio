import Defaults
import SwiftUI

struct HistoryListView: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(\.scenePhase) private var scenePhase

  private var pinnedItems: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible)
  }
  private var unpinnedItems: [HistoryItemDecorator] {
    appState.history.unpinnedItems.filter(\.isVisible)
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: FloatingGlassStyle.cardSpacing) {
        ForEach(pinnedItems) { item in
          CardItemView(item: item) {
            Task { appState.history.select(item) }
          }
        }

        ForEach(unpinnedItems) { item in
          CardItemView(item: item) {
            Task { appState.history.select(item) }
          }
        }
      }
      .padding(.horizontal, 14)
      .padding(.top, 10)
      .padding(.bottom, 12)
    }
    .frame(maxWidth: .infinity)
    .onChange(of: scenePhase) {
      if scenePhase == .active {
        searchFocused = true
        appState.navigator.select(
          item: appState.history.unpinnedItems.first ?? appState.history.pinnedItems.first
        )
      }
    }
  }
}
