import Defaults
import SwiftUI

// An NSPanel subclass that implements floating panel traits.
// https://stackoverflow.com/questions/46023769/how-to-show-a-window-without-stealing-focus-on-macos
class FloatingPanel<Content: View>: NSPanel, NSWindowDelegate {
  var isPresented: Bool = false
  var isDragging: Bool = false
  var statusBarButton: NSStatusBarButton?
  let onClose: () -> Void
  private var isPrewarming = false

  // SwiftUI does its first card/glass composition only after the panel is placed
  // onscreen. Briefly show an almost-transparent, noninteractive panel at launch so
  // the user's first shortcut can reuse the prepared backing store.
  func prewarm() {
    guard !isPresented, !isPrewarming else { return }
    isPrewarming = true
    if let screen = NSScreen.main {
      let visible = screen.visibleFrame
      setFrameOrigin(NSPoint(
        x: visible.minX + (visible.width - frame.width) / 2,
        y: visible.maxY - frame.height
      ))
    }
    alphaValue = 0.01
    ignoresMouseEvents = true
    orderFrontRegardless()
  }

  func finishPrewarming() {
    guard isPrewarming else { return }
    isPrewarming = false
    orderOut(nil)
    alphaValue = 1
    ignoresMouseEvents = false
  }

  override var isMovable: Bool {
    get { Defaults[.popupPosition] != .statusItem }
    set {}
  }

  init(
    contentRect: NSRect,
    identifier: String = "",
    statusBarButton: NSStatusBarButton? = nil,
    onClose: @escaping () -> Void,
    view: () -> Content
  ) {
    self.onClose = onClose

    super.init(
        contentRect: contentRect,
        styleMask: [.nonactivatingPanel, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    self.statusBarButton = statusBarButton
    self.identifier = NSUserInterfaceItemIdentifier(identifier)

    Defaults[.windowSize] = contentRect.size
    delegate = self

    animationBehavior = .none
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = false
    hidesOnDeactivate = false
    backgroundColor = .clear
    titlebarSeparatorStyle = .none
    // Follow the user's Light/Dark/Auto choice rather than forcing one appearance.
    appearance = Defaults[.appearanceMode].nsAppearance

    // Hide all traffic light buttons
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    let hostingView = NSHostingView(
      rootView: view()
        .ignoresSafeArea()
    )
    // Keep the window at its set size; don't let the horizontal card row grow it wider.
    hostingView.sizingOptions = []
    contentView = hostingView
    contentView?.layer?.cornerRadius = FloatingGlassStyle.trayRadius

    // A drag may set `isDragging` to keep the panel open while in flight. Clear it the
    // moment the mouse is released (inside or outside the app) so clicking outside can
    // close the panel again right after a drag ends.
    NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
      guard let self, self.isDragging else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.isDragging = false }
    }
    NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
      if let self, self.isDragging {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.isDragging = false }
      }
      return event
    }
  }

  func toggle(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    if isPresented {
      close()
    } else {
      open(height: height, at: popupPosition)
    }
  }

  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    isPrewarming = false
    alphaValue = 1
    ignoresMouseEvents = false
    // Pick up a Light/Dark/Auto change made in Settings, but only re-assign when it
    // actually changed — assigning NSWindow.appearance forces a full re-render.
    let desired = Defaults[.appearanceMode].nsAppearance
    if appearance?.name != desired?.name {
      appearance = desired
    }
    let size = Defaults[.windowSize]
    // Shelf layout has a fixed default height; fall back to it when no dynamic height is set.
    let targetHeight = height > 0 ? min(height, size.height) : size.height
    setContentSize(NSSize(width: min(frame.width, size.width), height: targetHeight))
    // Shelf drops down from the top-center of the screen, just under the menu bar.
    if let screen = NSScreen.main {
      let visible = screen.visibleFrame
      let originX = visible.minX + (visible.width - frame.width) / 2
      let originY = visible.maxY - frame.height
      setFrameOrigin(NSPoint(x: originX, y: originY))
    } else {
      setFrameOrigin(popupPosition.origin(size: frame.size, statusBarButton: statusBarButton))
    }
    orderFrontRegardless()
    makeKey()
    isPresented = true

    if popupPosition == .statusItem {
      DispatchQueue.main.async {
        self.statusBarButton?.isHighlighted = true
      }
    }
  }

  func verticallyResize(to newHeight: CGFloat) {
    var newSize = frame.size
    newSize.height = newHeight
    var newOrigin = frame.origin
    newOrigin.y += (frame.height - newSize.height)

    NSAnimationContext.runAnimationGroup { (context) in
      context.duration = 0.2
      animator().setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }
  }

  // Close automatically when out of focus, e.g. outside click.
  override func resignKey() {
    super.resignKey()
    // Don't hide if confirmation is shown.
    if NSApp.alertWindow == nil && !isDragging {
      close()
    }
  }

  override func close() {
    super.close()
    AppState.shared.appDelegate?.hidePreviewNow()
    isPresented = false
    statusBarButton?.isHighlighted = false
    onClose()
  }

  // Allow text inputs inside the panel can receive focus
  override var canBecomeKey: Bool {
    return true
  }
}
