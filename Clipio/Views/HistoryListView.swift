import Defaults
import SwiftUI

struct HistoryListView: View {
  static let coordinateSpaceName = "clipboard-shelf"

  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @State private var cardFrames: [UUID: CGRect] = [:]
  @State private var windowFrames: [UUID: CGRect] = [:]
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
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { windowFrames[item.id] = $0 }
            .onDisappear {
              Self.removeFrame(for: item.id, from: &cardFrames)
              Self.removeFrame(for: item.id, from: &windowFrames)
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
    .background(ShelfReorderMonitor(isSource: { point in
      Self.hoveredItemID(at: point, frames: windowFrames) != nil
    }, onReorder: { start, end in
      guard let sourceID = Self.hoveredItemID(at: start, frames: windowFrames),
            let targetID = Self.hoveredItemID(at: end, frames: windowFrames),
            let source = orderedItems.first(where: { $0.id == sourceID }),
            let target = orderedItems.first(where: { $0.id == targetID }),
            let targetFrame = windowFrames[targetID] else { return }
      appState.history.move(source, relativeTo: target, after: end.x > targetFrame.midX)
    }))
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

struct ShelfDragArbitration {
  enum Decision { case wait, reorder, export }
  private var origin = CGPoint.zero
  private var startTime: TimeInterval = 0
  private var decision: Decision = .wait

  mutating func begin(at point: CGPoint, time: TimeInterval) {
    origin = point
    startTime = time
    decision = .wait
  }

  mutating func move(to point: CGPoint, time: TimeInterval) -> Decision {
    guard decision == .wait else { return decision }
    guard hypot(point.x - origin.x, point.y - origin.y) > 4 else { return .wait }
    decision = time - startTime >= 0.45 ? .reorder : .export
    return decision
  }
}

/// Reserve a held mouse drag for in-shelf reordering before AppKit starts an export.
struct ShelfReorderMonitor: NSViewRepresentable {
  let isSource: (CGPoint) -> Bool
  let onReorder: (CGPoint, CGPoint) -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    context.coordinator.install(view: view)
    return view
  }
  func updateNSView(_ view: NSView, context: Context) {
    context.coordinator.isSource = isSource
    context.coordinator.onReorder = onReorder
  }
  static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.remove() }

  final class Coordinator {
    weak var view: NSView?
    var monitor: Any?
    var start: CGPoint?
    var arbitration = ShelfDragArbitration()
    var reordering = false
    var isSource: (CGPoint) -> Bool = { _ in false }
    var onReorder: (CGPoint, CGPoint) -> Void = { _, _ in }

    func install(view: NSView) {
      self.view = view
      monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
        guard let self, let window = self.view?.window, event.window === window,
              let content = window.contentView else { return event }
        let point = CGPoint(x: event.locationInWindow.x, y: content.bounds.height - event.locationInWindow.y)
        switch event.type {
        case .leftMouseDown:
          start = event.modifierFlags.isDisjoint(with: [.command, .shift, .option, .control]) && isSource(point) ? point : nil
          arbitration.begin(at: point, time: event.timestamp)
          reordering = false
        case .leftMouseDragged:
          guard start != nil else { return event }
          switch arbitration.move(to: point, time: event.timestamp) {
          case .wait: return nil
          case .reorder: reordering = true; return nil
          case .export: start = nil
          }
        case .leftMouseUp:
          defer { start = nil; reordering = false }
          if reordering, let start { onReorder(start, point) }
        default: break
        }
        return event
      }
    }
    func remove() { if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil } }
    deinit { remove() }
  }
}
