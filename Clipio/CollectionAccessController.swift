import AppKit
import Observation
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

/// The system positions the idle menu item; a separate drag receiver stays below the menu bar.
@MainActor
final class CollectionAccessController: NSObject {
  private let store: CollectionStore
  let statusItem: NSStatusItem
  private let panel: NSPanel
  private let dropView = CollectionEntryDropView(frame: .zero)
  private let hosting = NSHostingView(rootView: CollectionEntryLabel(dragging: false, targeted: false, action: {}))
  private var releaseWork: DispatchWorkItem?
  private var monitors: [Any] = []
  private var screenObserver: NSObjectProtocol?
  private var dragChangeCount = -1
  private var showingDrag = false
  private var dropTargeted = false
  /// Set while the full shelf was sprung open by holding a drag on the pill.
  private var openedForDrag = false
  private var itemCountAtSpring = 0
  private var springWork: DispatchWorkItem?
  private var hideGeneration = 0
  private var seenReceiptGeneration = 0
  private var showingReceipt = false
  private var receiptToken = UUID()
  private var receiptDismissWork: DispatchWorkItem?
  /// How long a drag must rest on the pill before it unfolds into the full shelf.
  static let springDelay: TimeInterval = 0.6
  private let dragPasteboard = NSPasteboard(name: .drag)

  init(store: CollectionStore) {
    self.store = store
    seenReceiptGeneration = store.receiptGeneration
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    super.init()
    statusItem.isVisible = false
    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: nil)
      button.image?.isTemplate = true
      button.target = self
      button.action = #selector(openCollection)
      button.toolTip = NSLocalizedString("collection_open", comment: "")
      button.setAccessibilityLabel(NSLocalizedString("collection_open", comment: ""))
      button.setAccessibilityIdentifier("collection-status-item")
    }
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.hidesOnDeactivate = false
    hosting.sizingOptions = []
    hosting.autoresizingMask = [.width, .height]
    dropView.addSubview(hosting)
    panel.contentView = dropView
    dropView.onTargetChange = { [weak self] targeted in
      guard let self, self.dropTargeted != targeted else { return }
      self.dropTargeted = targeted
      self.springWork?.cancel()
      if targeted {
        // Spring-loaded like a Finder folder: rest on the pill to unfold the shelf.
        let work = DispatchWorkItem { [weak self] in self?.springOpen() }
        self.springWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.springDelay, execute: work)
      }
      self.updateEntry()
    }
    dropView.onDrop = { [weak self] providers in
      guard let self, !self.store.isExporting else { return }
      Task { await CollectionImporter.collect(providers, into: self.store) }
    }
    dropView.onPromises = { [weak self] receivers in self?.receivePromises(receivers) }
    observeCount()
    let events: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
    if let monitor = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] in self?.handle($0) }) {
      monitors.append(monitor)
    }
    if let monitor = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
      self?.handle(event)
      return event
    }) { monitors.append(monitor) }
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in self?.updateEntry() }
    }
  }

  deinit {
    releaseWork?.cancel()
    receiptDismissWork?.cancel()
    monitors.forEach(NSEvent.removeMonitor)
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    let entryPanel = panel
    let entryStatusItem = statusItem
    Task { @MainActor in
      entryPanel.orderOut(nil)
      NSStatusBar.system.removeStatusItem(entryStatusItem)
    }
  }

  private func observeCount() {
    withObservationTracking {
      _ = store.items.count
      _ = store.receiptGeneration
      _ = AppState.shared.shelfExpanded
      _ = AppState.shared.shelfMode
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.updateEntry()
        self?.observeCount()
      }
    }
    updateEntry()
  }

  private func handle(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown:
      releaseWork?.cancel()
      if showingReceipt {
        showingReceipt = false
        receiptToken = UUID()
        receiptDismissWork?.cancel()
        updateEntry()
      }
      dragChangeCount = dragPasteboard.changeCount
    case .leftMouseDragged:
      guard !store.isExporting, dragPasteboard.changeCount != dragChangeCount,
            dragPasteboard.types?.contains(where: { type in
              type == .fileURL || type == .png || type == .tiff || type == .URL
                || NSFilePromiseReceiver.readableDraggedTypes.contains(type.rawValue)
            }) == true else { return }
      releaseWork?.cancel()
      let mouse = NSEvent.mouseLocation
      if openedForDrag {
        // Dragging back out of the sprung-open shelf folds it into the pill again.
        if let shelf = AppState.shared.appDelegate?.panel, !shelf.frame.insetBy(dx: -24, dy: -24).contains(mouse) {
          collapseSprungShelf()
          showingDrag = true
          updateEntry()
        }
        return
      }
      // A drag that starts inside an already open shelf (e.g. a clipboard card being
      // dragged out) never summons the pill.
      guard !AppState.shared.shelfExpanded else { return }
      let pointerScreen = NSScreen.screens.first { $0.frame.contains(mouse) }
      if !showingDrag || panel.screen != pointerScreen {
        showingDrag = true
        updateEntry()
      }
    case .leftMouseUp:
      releaseWork?.cancel()
      springWork?.cancel()
      guard showingDrag || dropTargeted || openedForDrag else { return }
      let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        if self.openedForDrag {
          // Keep the shelf open only when something actually landed in it; a
          // cancelled or rejected drag leaves nothing behind.
          let received = self.store.items.count != self.itemCountAtSpring || self.store.importingCount > 0
          if received {
            AppState.shared.appDelegate?.panel.isDragging = false
            self.openedForDrag = false
          } else {
            self.collapseSprungShelf()
          }
        }
        self.showingDrag = false
        self.dropTargeted = false
        self.updateEntry()
      }
      releaseWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    default: break
    }
  }

  private func springOpen() {
    guard dropTargeted, !openedForDrag, !store.isExporting else { return }
    openedForDrag = true
    itemCountAtSpring = store.items.count
    dropTargeted = false
    showingDrag = false
    let state = AppState.shared
    state.switchShelf(to: .collection)
    state.appDelegate?.panel.isDragging = true
    if state.popup.isClosed() { state.popup.open(height: state.popup.height) }
    if let screen = panel.screen ?? NSScreen.main, let shelf = state.appDelegate?.panel {
      let top = screen.frame.maxY - max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
      shelf.setFrameOrigin(NSPoint(x: screen.frame.midX - shelf.frame.width / 2, y: top - shelf.frame.height))
    }
    updateEntry()
  }

  private func collapseSprungShelf() {
    guard openedForDrag else { return }
    openedForDrag = false
    let state = AppState.shared
    state.appDelegate?.panel.isDragging = false
    if !state.popup.isClosed() { state.popup.close() }
  }

  private func updateEntry() {
    if seenReceiptGeneration != store.receiptGeneration {
      seenReceiptGeneration = store.receiptGeneration
      showingReceipt = true
      receiptDismissWork?.cancel()
      let token = UUID()
      receiptToken = token
      Notifier.play(sound: .collectionReceipt)
      let work = DispatchWorkItem { [weak self] in
        guard let self, self.receiptToken == token else { return }
        self.showingReceipt = false
        self.updateEntry()
      }
      receiptDismissWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.05, execute: work)
    }
    // Never put a custom window in the menu bar. A real status item reserves space
    // alongside other apps, and its visibility does not change on Tab or during a drag.
    let hasItems = !store.items.isEmpty
    if statusItem.isVisible != hasItems { statusItem.isVisible = hasItems }
    panel.ignoresMouseEvents = showingReceipt && !showingDrag
    guard showingReceipt || (showingDrag && !openedForDrag) else {
      hide()
      return
    }
    let screen = (showingDrag ? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } : panel.screen)
      ?? NSScreen.main
    guard let screen else { return }
    let target = Self.dragEntryFrame(
      screenFrame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
      menuBarHeight: NSStatusBar.system.thickness, targeted: dropTargeted
    )
    hosting.rootView = CollectionEntryLabel(
      dragging: true, targeted: dropTargeted, received: showingReceipt, receiptGeneration: seenReceiptGeneration
    ) { [weak self] in
      self?.openCollection()
    }
    hideGeneration += 1
    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let appearing = !panel.isVisible || panel.alphaValue < 1
    if appearing && !reduceMotion {
      // Grow out of a slightly smaller, transparent pill so it arrives softly.
      if !panel.isVisible {
        panel.alphaValue = 0
        panel.setFrame(target.insetBy(dx: target.width * 0.12, dy: target.height * 0.12), display: false)
      }
      hosting.frame = dropView.bounds
      panel.orderFrontRegardless()
    }
    if (panel.frame != target || appearing) && !reduceMotion && screen.frame.contains(panel.frame.origin) {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.32
        // Gentle overshoot: a soft spring rather than a linear slide.
        context.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 1.25, 0.55, 1)
        panel.animator().setFrame(target, display: true)
        panel.animator().alphaValue = 1
      }
    } else {
      panel.setFrame(target, display: true)
      panel.alphaValue = 1
    }
    hosting.frame = dropView.bounds
    if !panel.isVisible { panel.orderFrontRegardless() }
  }

  private func hide() {
    guard panel.isVisible else { return }
    hideGeneration += 1
    let generation = hideGeneration
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      panel.orderOut(nil)
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      context.timingFunction = CAMediaTimingFunction(name: .easeIn)
      panel.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self, self.hideGeneration == generation else { return }
        self.panel.orderOut(nil)
        self.panel.alphaValue = 1
      }
    }
  }

  static func dragEntryFrame(
    screenFrame: NSRect, safeAreaTop: CGFloat, menuBarHeight: CGFloat, targeted: Bool
  ) -> NSRect {
    let height: CGFloat = targeted ? 54 : 46
    let width: CGFloat = targeted ? 210 : 184
    return NSRect(
      x: screenFrame.midX - width / 2,
      y: screenFrame.maxY - max(safeAreaTop, menuBarHeight) - height - 8,
      width: width, height: height
    )
  }

  @objc private func openCollection() {
    guard !store.isExporting else { return }
    let state = AppState.shared
    state.switchShelf(to: .collection)
    if state.popup.isClosed() { state.popup.open(height: state.popup.height) }
  }

  private func receivePromises(_ receivers: [NSFilePromiseReceiver]) {
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Clipio-Promises-\(UUID().uuidString)")
    do { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
    catch { store.lastError = error.localizedDescription; return }
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.qualityOfService = .utility
    // Each receiver may promise several files, each delivered in its own callback.
    let fileCount = receivers.reduce(0) { $0 + max(1, $1.fileNames.count) }
    let batch = fileCount > 1 ? UUID() : nil
    let store = self.store
    let receipt = CollectionImportBatch(count: fileCount, store: store)
    for receiver in receivers {
      receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: queue) { url, error in
        let image = Result { () throws -> CollectionImage in
          if let error { throw error }
          return try CollectionImage(contentsOf: url)
        }
        DispatchQueue.main.async {
          do { receipt.complete(id: try store.addImage(image.get(), batch: batch)) }
          catch { receipt.complete(error: error) }
          try? FileManager.default.removeItem(at: url)
        }
      }
    }
  }
}

private struct CollectionEntryLabel: View {
  let dragging: Bool
  let targeted: Bool
  var received = false
  var receiptGeneration = 0
  let action: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: received ? "checkmark" : (dragging ? "tray.and.arrow.down" : "tray"))
          .symbolEffect(.bounce, value: targeted)
        if dragging { Text("collection_drop_hint") }
      }
      .font(.system(size: dragging ? 12.5 : 11, weight: .medium))
      .foregroundStyle(.primary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .modifier(CollectionEntrySurface(radius: dragging ? 22 : 13, targeted: targeted || received))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .padding(3)
    .keyframeAnimator(initialValue: CGFloat(1), trigger: reduceMotion ? 0 : receiptGeneration) { content, scale in
      content.scaleEffect(scale)
    } keyframes: { _ in
      LinearKeyframe(1.045, duration: 0.18)
      SpringKeyframe(1, duration: 0.32, spring: .smooth(duration: 0.32))
    }
    .accessibilityLabel(Text(received ? "collection_received" : (dragging ? "collection_drop_hint" : "collection_open")))
    .accessibilityIdentifier("collection-entry")
  }
}

/// The same clear glass, scrim and spectral rim as the shelf, so the pill reads as a
/// small piece of it. While a drag rests on it the rim brightens with a cool glow.
private struct CollectionEntrySurface: ViewModifier {
  let radius: CGFloat
  let targeted: Bool

  func body(content: Content) -> some View {
    content.background {
      Color.clear.modifier(ShelfGlassSurface(radius: radius))
        .overlay(ShelfGlassRim(radius: radius))
        .overlay {
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(FloatingGlassStyle.rimTint.opacity(targeted ? 0.55 : 0), lineWidth: 1.5)
            .shadow(color: FloatingGlassStyle.rimTint.opacity(targeted ? 0.45 : 0), radius: 6)
            .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.2), value: targeted)
    }
  }
}

private final class CollectionEntryDropView: NSView {
  var onTargetChange: ((Bool) -> Void)?
  var onDrop: (([NSItemProvider]) -> Void)?
  var onPromises: (([NSFilePromiseReceiver]) -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    let types: [NSPasteboard.PasteboardType] = [.fileURL, .png, .tiff, .URL]
    registerForDraggedTypes(types + promiseTypes)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard !AppState.shared.collection.isExporting else { return [] }
    onTargetChange?(true)
    return .copy
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    onTargetChange?(false)
  }

  override func draggingEnded(_ sender: NSDraggingInfo) {
    onTargetChange?(false)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
      // Carry any image bytes on the same item too, so a URL into another app's private
      // storage (e.g. Messages) can fall back to a copy of the image.
      let items = pasteboard.pasteboardItems ?? []
      onDrop?(urls.enumerated().map { index, url in
        let provider = NSItemProvider(item: url as NSURL, typeIdentifier: UTType.fileURL.identifier)
        if items.count == urls.count {
          let item = items[index]
          for type in item.types where UTType(type.rawValue)?.conforms(to: .image) == true {
            guard let data = item.data(forType: type) else { continue }
            provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
              completion(data, nil)
              return nil
            }
          }
        }
        return provider
      })
      return true
    }
    if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver], !receivers.isEmpty {
      onPromises?(receivers)
      return true
    }
    let providers = (pasteboard.pasteboardItems ?? []).map { item in
      let provider = NSItemProvider()
      for type in item.types {
        if let data = item.data(forType: type) {
          provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
            completion(data, nil)
            return nil
          }
        }
      }
      return provider
    }
    guard !providers.isEmpty else { return false }
    onDrop?(providers)
    return true
  }
}
