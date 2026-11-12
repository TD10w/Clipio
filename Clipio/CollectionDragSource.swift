import AppKit
import OSLog
import SwiftUI

/// `ids` is one card's items: a single item, or every member of a collapsed Stack.
/// `onClick` replaces plain-click selection (a Stack expands instead).
struct CollectionDragSource: NSViewRepresentable {
  let ids: [UUID]
  let store: CollectionStore
  var onClick: (() -> Void)?

  func makeNSView(context: Context) -> CollectionDragNSView {
    let view = CollectionDragNSView()
    updateNSView(view, context: context)
    return view
  }

  func updateNSView(_ view: CollectionDragNSView, context: Context) {
    view.itemIDs = Set(ids)
    view.store = store
    view.onClick = onClick
  }
}

final class CollectionDragNSView: NSView, NSDraggingSource {
  var itemIDs: Set<UUID> = []
  var store: CollectionStore?
  var onClick: (() -> Void)?
  private var mouseDownPoint = NSPoint.zero
  private var activeExport: CollectionExport?
  private var didDrag = false
  private static let logger = Logger(subsystem: "com.clipio.app", category: "CollectionDrag")

  override func mouseDown(with event: NSEvent) {
    mouseDownPoint = event.locationInWindow
    didDrag = false
    guard let store, !itemIDs.isEmpty else { return }
    let extending = !event.modifierFlags.isDisjoint(with: [.command, .shift])
    if extending {
      if itemIDs.isSubset(of: store.selectedIDs) {
        store.selectedIDs.subtract(itemIDs)
      } else {
        store.selectedIDs.formUnion(itemIDs)
      }
    } else if !itemIDs.isSubset(of: store.selectedIDs) {
      store.selectedIDs = itemIDs
    }
  }

  override func mouseUp(with event: NSEvent) {
    guard !didDrag, event.modifierFlags.isDisjoint(with: [.command, .shift]), !itemIDs.isEmpty else { return }
    store?.selectedIDs = itemIDs
    onClick?()
  }

  override func mouseDragged(with event: NSEvent) {
    guard !didDrag, let store, !store.isExporting, !itemIDs.isEmpty,
          hypot(event.locationInWindow.x - mouseDownPoint.x, event.locationInWindow.y - mouseDownPoint.y) > 4 else { return }
    didDrag = true
    do {
      let ids = itemIDs.isSubset(of: store.selectedIDs) ? store.selectedIDs : itemIDs
      let export = try store.prepareExport(ids: ids)
      var began = false
      defer { if !began { store.cancelPreparedExport(export) } }
      let idsByURL = Dictionary(uniqueKeysWithValues: export.exportedURLs.map { ($0.value, $0.key) })
      let draggingItems = try export.urls.map { url in
        let writer: NSPasteboardWriting
        if let id = idsByURL[url], let payload = try store.payload(for: id) {
          writer = CollectionPayloadWriter(fileURL: url, payload: payload)
        } else { writer = url as NSURL }
        let item = NSDraggingItem(pasteboardWriter: writer)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 48, height: 48), contents: icon)
        return item
      }
      Self.logger.notice("Collection drag began: items=\(export.ids.count), mask=\(export.operation.rawValue)")
      activeExport = export
      began = true
      store.isExporting = true
      AppState.shared.appDelegate?.panel.isDragging = true
      beginDraggingSession(with: draggingItems, event: event, source: self)
    } catch {
      store.lastError = error.localizedDescription
      store.refreshAvailability()
    }
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    context == .outsideApplication ? (activeExport?.operation ?? []) : []
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    guard let export = activeExport else { return }
    activeExport = nil
    Self.logger.notice("Collection drag ended: items=\(export.ids.count), operation=\(operation.rawValue)")
    if let store {
      Task { @MainActor in await store.completeExport(export, operation: operation) }
    } else { export.endAccess() }
    AppState.shared.appDelegate?.panel.isDragging = false
  }
}

/// File targets receive the staged file URL while text/link targets receive the
/// original payload. NSURL remains responsible for its file URL representations.
final class CollectionPayloadWriter: NSObject, NSPasteboardWriting {
  let fileURL: NSURL
  let payload: CollectionPayload

  init(fileURL: URL, payload: CollectionPayload) {
    self.fileURL = fileURL as NSURL
    self.payload = payload
  }

  func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    var types: [NSPasteboard.PasteboardType] = [.string]
    if case .link = payload { types.append(.URL) }
    return types + fileURL.writableTypes(for: pasteboard).filter { !types.contains($0) }
  }

  func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    if type == .string { return payload.plainText }
    if type == .URL, case .link(let url) = payload { return url.absoluteString }
    return fileURL.pasteboardPropertyList(forType: type)
  }
}
