import Defaults
import SwiftUI

// Animation tunables for FloatingPanel — one-line changes to dial in the feel.
private enum FloatingPanelAnim {
  static let openDuration: TimeInterval = 0.14
  static let closeDuration: TimeInterval = 0.10
  static let openFromScale: CGFloat = 0.96
}

// An NSPanel subclass that implements floating panel traits.
// https://stackoverflow.com/questions/46023769/how-to-show-a-window-without-stealing-focus-on-macos
class FloatingPanel<Content: View>: NSPanel, NSWindowDelegate {
  var isPresented: Bool = false
  var isDragging: Bool = false
  var statusBarButton: NSStatusBarButton?
  let onClose: () -> Void
  private var isPrewarming = false
  private var isAnimatingClose = false

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

  private func commitClose() {
    super.close()
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
    // Cancel any in-progress close animation so we start clean.
    isAnimatingClose = false
    contentView?.layer?.removeAllAnimations()
    // Snap window alpha to cancel any in-flight close animator.
    NSAnimationContext.beginGrouping()
    NSAnimationContext.current.duration = 0
    animator().alphaValue = 0
    NSAnimationContext.endGrouping()

    isPrewarming = false
    ignoresMouseEvents = false
    let desired = Defaults[.appearanceMode].nsAppearance
    if appearance?.name != desired?.name {
      appearance = desired
    }
    let size = Defaults[.windowSize]
    let targetHeight = height > 0 ? min(height, size.height) : size.height
    setContentSize(NSSize(width: min(frame.width, size.width), height: targetHeight))
    if let screen = NSScreen.main {
      let visible = screen.visibleFrame
      let originX = visible.minX + (visible.width - frame.width) / 2
      let originY = visible.maxY - frame.height
      setFrameOrigin(NSPoint(x: originX, y: originY))
    } else {
      setFrameOrigin(popupPosition.origin(size: frame.size, statusBarButton: statusBarButton))
    }

    // Start invisible + scaled down, then pop into view.
    alphaValue = 0
    contentView?.wantsLayer = true
    // Set model at final (identity) so animation removal snaps to full-size correctly.
    contentView?.layer?.transform = CATransform3DIdentity

    orderFrontRegardless()
    makeKey()
    isPresented = true

    // Fade alpha via NSAnimationContext (implicit NSWindow animation).
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = FloatingPanelAnim.openDuration
      ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
      animator().alphaValue = 1
    }

    // Scale via explicit CABasicAnimation; fromValue starts at 0.96, model already at 1.0.
    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
    scaleAnim.fromValue = FloatingPanelAnim.openFromScale
    scaleAnim.duration = FloatingPanelAnim.openDuration
    scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
    contentView?.layer?.add(scaleAnim, forKey: "popOpen")

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
    guard isPresented else {
      super.close()
      return
    }
    guard !isAnimatingClose else { return }
    isAnimatingClose = true

    AppState.shared.appDelegate?.hidePreviewNow()
    isPresented = false
    statusBarButton?.isHighlighted = false

    // Set model at final (scaled-down) so removal snaps correctly; fromValue = 1.0.
    contentView?.layer?.transform = CATransform3DMakeScale(FloatingPanelAnim.openFromScale, FloatingPanelAnim.openFromScale, 1)
    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
    scaleAnim.fromValue = 1.0
    scaleAnim.duration = FloatingPanelAnim.closeDuration
    scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
    contentView?.layer?.add(scaleAnim, forKey: "popClose")

    NSAnimationContext.runAnimationGroup({ ctx in
      ctx.duration = FloatingPanelAnim.closeDuration
      ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
      animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isAnimatingClose = false
        // Reset layer to identity so the next open starts clean.
        self.contentView?.layer?.removeAllAnimations()
        self.contentView?.layer?.transform = CATransform3DIdentity
        self.alphaValue = 1
        self.commitClose()   // calls super.close() — orders out the window
        self.onClose()
      }
    })
  }

  // Allow text inputs inside the panel can receive focus
  override var canBecomeKey: Bool {
    return true
  }
}
