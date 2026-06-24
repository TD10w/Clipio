import AppKit
import Observation
import SwiftUI

// Holds the item currently shown in the preview popup so the SwiftUI content updates
// reactively as the user hovers different cards.
@Observable
final class PreviewPopupModel {
  var item: HistoryItemDecorator?
}

// A small, non-interactive floating panel that shows an enlarged preview of the
// hovered card below the shelf. It never becomes key, so showing it does not make the
// main shelf resign key and close.
final class PreviewPopupPanel: NSPanel {
  let model = PreviewPopupModel()

  static let popupWidth: CGFloat = 620
  static let popupHeight: CGFloat = 540

  private var hideWorkItem: DispatchWorkItem?

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: Self.popupWidth, height: Self.popupHeight),
      styleMask: [.nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    hidesOnDeactivate = false
    ignoresMouseEvents = true

    let host = NSHostingView(rootView: PreviewPopupContent(model: model))
    host.sizingOptions = []
    contentView = host
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  // Show the preview for `item`, centered just below the shelf window.
  func show(item: HistoryItemDecorator, below shelfFrame: NSRect) {
    hideWorkItem?.cancel()
    model.item = item
    item.ensureThumbnailImage()

    var originX = shelfFrame.midX - Self.popupWidth / 2
    var originY = shelfFrame.minY - Self.popupHeight - 8

    // Keep the popup fully on screen.
    if let visible = NSScreen.main?.visibleFrame {
      originX = min(max(originX, visible.minX + 8), visible.maxX - Self.popupWidth - 8)
      originY = max(originY, visible.minY + 8)
    }

    setFrameOrigin(NSPoint(x: originX, y: originY))
    orderFront(nil)
  }

  // Hide after a short delay so moving between adjacent cards doesn't flicker. Only
  // hides if no other card has since taken over the preview (checked by item id).
  func scheduleHide(forItemId id: UUID) {
    hideWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.model.item?.id == id else { return }
      let hidden = self.model.item
      self.orderOut(nil)
      self.model.item = nil
      hidden?.releasePreviewImage()
    }
    hideWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
  }

  func hideNow() {
    hideWorkItem?.cancel()
    let hidden = model.item
    orderOut(nil)
    model.item = nil
    hidden?.releasePreviewImage()
  }
}

private struct PreviewPopupContent: View {
  @Bindable var model: PreviewPopupModel

  var body: some View {
    Group {
      if let item = model.item {
        PreviewItemView(item: item)
          .id(item.id)
          .padding(14)
          .frame(
            width: PreviewPopupPanel.popupWidth,
            height: PreviewPopupPanel.popupHeight,
            alignment: .topLeading
          )
          .background(.regularMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
          )
      } else {
        Color.clear
      }
    }
    .frame(width: PreviewPopupPanel.popupWidth, height: PreviewPopupPanel.popupHeight, alignment: .top)
  }
}
