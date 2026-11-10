import AppKit
import SwiftUI

struct CollectionDragSource: NSViewRepresentable {
  let id: UUID
  let store: CollectionStore

  func makeNSView(context: Context) -> CollectionDragNSView {
    let view = CollectionDragNSView()
    view.itemID = id
    view.store = store
    return view
  }

  func updateNSView(_ view: CollectionDragNSView, context: Context) {
    view.itemID = id
    view.store = store
  }
}

final class CollectionDragNSView: NSView, NSDraggingSource {
  var itemID: UUID?
  var store: CollectionStore?
  private var mouseDownPoint = NSPoint.zero
  private var activeExport: CollectionExport?
  private var didDrag = false

  override func mouseDown(with event: NSEvent) {
    mouseDownPoint = event.locationInWindow
    didDrag = false
    guard let store, let itemID else { return }
    let extending = !event.modifierFlags.isDisjoint(with: [.command, .shift])
    if extending || !store.selectedIDs.contains(itemID) {
      store.select(itemID, extending: extending)
    }
  }

  override func mouseUp(with event: NSEvent) {
    guard !didDrag, event.modifierFlags.isDisjoint(with: [.command, .shift]), let itemID else { return }
    store?.select(itemID, extending: false)
  }

  override func mouseDragged(with event: NSEvent) {
    guard !didDrag, let store, let itemID,
          hypot(event.locationInWindow.x - mouseDownPoint.x, event.locationInWindow.y - mouseDownPoint.y) > 4 else { return }
    didDrag = true
    do {
      let ids = store.selectedIDs.contains(itemID) ? store.selectedIDs : [itemID]
      let export = try store.prepareExport(ids: ids)
      let draggingItems = export.urls.map { url in
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 48, height: 48), contents: icon)
        return item
      }
      activeExport = export
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
    store?.perform { try store?.finishExport(export, operation: operation) }
    store?.isExporting = false
    AppState.shared.appDelegate?.panel.isDragging = false
  }
}
