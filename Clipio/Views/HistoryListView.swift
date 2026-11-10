import Defaults
import SwiftUI

struct HistoryListView: View {
  static let coordinateSpaceName = "clipboard-shelf"

  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @State private var cardFrames: [UUID: CGRect] = [:]
  @State private var hoveredID: UUID?

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

  static func removeFrame(for id: UUID, from frames: inout [UUID: CGRect]) {
    frames.removeValue(forKey: id)
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      ScrollViewReader { proxy in
        LazyHStack(spacing: FloatingGlassStyle.cardSpacing) {
          ForEach(orderedItems) { item in
            CardItemView(item: item, isHovered: hoveredID == item.id) {
              Task { appState.history.select(item) }
            }
            .id(item.id)
            .onGeometryChange(for: CGRect.self) { proxy in
              proxy.frame(in: .named(Self.coordinateSpaceName))
            } action: { frame in
              if cardFrames[item.id] != frame {
                cardFrames[item.id] = frame
              }
            }
            .onDisappear {
              Self.removeFrame(for: item.id, from: &cardFrames)
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
    // The shelf unfolds with a parent scale transform. Measure and hit-test inside
    // the shelf so cached card frames cannot retain an intermediate global scale.
    .coordinateSpace(name: Self.coordinateSpaceName)
    .onContinuousHover(coordinateSpace: .named(Self.coordinateSpaceName)) { phase in
      let id: UUID?
      if case .active(let point) = phase {
        id = Self.hoveredItemID(at: point, frames: cardFrames)
      } else {
        id = nil
      }
      if hoveredID != id {
        if let old = hoveredID, let item = orderedItems.first(where: { $0.id == old }) {
          appState.appDelegate?.hidePreviewSoon(for: item)
        }
        hoveredID = id
        if let id, let item = orderedItems.first(where: { $0.id == id }) {
          appState.appDelegate?.showPreview(for: item)
        }
      }
      guard let id else { return }
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
