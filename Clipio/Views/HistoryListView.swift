import Defaults
import SwiftUI

struct HistoryListView: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @State private var cardFrames: [UUID: CGRect] = [:]

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

  static func hoveredItemID(at point: CGPoint, frames: [UUID: CGRect]) -> UUID? {
    frames.first { $0.value.contains(point) }?.key
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
            .onGeometryChange(for: CGRect.self) { proxy in
              proxy.frame(in: .global)
            } action: { frame in
              if cardFrames[item.id] != frame {
                cardFrames[item.id] = frame
              }
            }
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
    .onContinuousHover(coordinateSpace: .global) { phase in
      guard case .active(let point) = phase,
            let id = Self.hoveredItemID(at: point, frames: cardFrames) else { return }
      let navigator = appState.navigator
      if !navigator.isKeyboardNavigating && !navigator.isMultiSelectInProgress {
        navigator.selectWithoutScrolling(id: id)
      } else {
        navigator.hoverSelectionWhileKeyboardNavigating = id
      }
    }
    .onChange(of: orderedItems.map(\.id)) { _, visibleIDs in
      cardFrames = cardFrames.filter { visibleIDs.contains($0.key) }
    }
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
