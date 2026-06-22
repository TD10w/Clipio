import Defaults
import SwiftUI

struct HistoryListView: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(\.scenePhase) private var scenePhase
  @Default(.pinTo) private var pinTo

  private var pinnedItems: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible)
  }
  private var unpinnedItems: [HistoryItemDecorator] {
    appState.history.unpinnedItems.filter(\.isVisible)
  }

  static func orderedItems<Item>(pinned: [Item], unpinned: [Item], pinTo: PinsPosition) -> [Item] {
    switch pinTo {
    case .top:
      return pinned + unpinned
    case .bottom:
      return unpinned + pinned
    }
  }

  private var orderedItems: [HistoryItemDecorator] {
    Self.orderedItems(pinned: pinnedItems, unpinned: unpinnedItems, pinTo: pinTo)
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      ScrollViewReader { proxy in
        LazyHStack(spacing: FloatingGlassStyle.cardSpacing) {
          ForEach(orderedItems) { item in
            CardItemView(item: item) {
              Task { appState.history.select(item) }
            }
            .id(item.id)
          }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .task(id: appState.navigator.scrollTarget) {
          guard let selection = appState.navigator.scrollTarget else { return }
          try? await Task.sleep(for: .milliseconds(10))
          guard !Task.isCancelled else { return }
          withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(selection, anchor: .center)
          }
          appState.navigator.scrollTarget = nil
        }
      }
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
