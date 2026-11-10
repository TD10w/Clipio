import AppKit
import Observation
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

/// A small entry beside the notch. It never becomes key; the existing shelf owns all editing.
@MainActor
final class CollectionAccessController {
  private let store: CollectionStore
  private let panel: NSPanel
  private let dropView = CollectionEntryDropView(frame: .zero)
  private let hosting = NSHostingView(rootView: CollectionEntryLabel(dragging: false, action: {}))
  private var releaseWork: DispatchWorkItem?
  private var monitors: [Any] = []
  private var screenObserver: NSObjectProtocol?
  private var dragChangeCount = -1
  private var showingDrag = false
  private var openedForDrag = false
  private let dragPasteboard = NSPasteboard(name: .drag)

  init(store: CollectionStore) {
    self.store = store
    panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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
    dropView.onEnter = { [weak self] in self?.openCollection(forDrag: true) }
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
    monitors.forEach(NSEvent.removeMonitor)
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    let entryPanel = panel
    Task { @MainActor in entryPanel.orderOut(nil) }
  }

  private func observeCount() {
    withObservationTracking {
      _ = store.items.count
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
      dragChangeCount = dragPasteboard.changeCount
    case .leftMouseDragged:
      guard !store.isExporting, dragPasteboard.changeCount != dragChangeCount,
            dragPasteboard.types?.contains(where: { type in
              type == .fileURL || type == .png || type == .tiff || type == .URL
                || NSFilePromiseReceiver.readableDraggedTypes.contains(type.rawValue)
            }) == true else { return }
      releaseWork?.cancel()
      let pointerScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
      if !showingDrag || panel.screen != pointerScreen {
        showingDrag = true
        updateEntry()
      }
      // Welcome immediately; unfold as the pointer approaches the shelf's actual
      // footprint below the notch. No trip through the menu bar is required.
      if !openedForDrag, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
        let top = screen.frame.maxY - max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
        let approach = NSRect(x: screen.frame.midX - 410, y: top - 260, width: 820, height: 260)
        if approach.contains(NSEvent.mouseLocation) { openCollection(forDrag: true) }
      }
    case .leftMouseUp:
      releaseWork?.cancel()
      let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        self.showingDrag = false
        if self.openedForDrag {
          AppState.shared.appDelegate?.panel.isDragging = false
          self.openedForDrag = false
        }
        self.updateEntry()
      }
      releaseWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    default: break
    }
  }

  private func updateEntry() {
    let collectionIsOpen = AppState.shared.shelfExpanded && AppState.shared.shelfMode == .collection
    guard (showingDrag || !store.items.isEmpty), !openedForDrag, !collectionIsOpen else {
      panel.orderOut(nil)
      return
    }
    let screen = (showingDrag ? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } : NSScreen.main)
      ?? NSScreen.main
    guard let screen else { return }
    let topInset = max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
    let height: CGFloat = showingDrag ? 52 : min(30, topInset)
    let width: CGFloat = showingDrag ? 220 : 44
    let notchRight = screen.auxiliaryTopRightArea?.minX ?? (screen.frame.midX + 80)
    let target = NSRect(
      x: showingDrag ? screen.frame.midX - width / 2 : min(notchRight + 6, screen.frame.maxX - width - 12),
      y: showingDrag ? screen.frame.maxY - topInset - height - 8
        : screen.frame.maxY - topInset + (topInset - height) / 2,
      width: width, height: height
    )
    hosting.rootView = CollectionEntryLabel(dragging: showingDrag) { [weak self] in
      self?.openCollection(forDrag: false)
    }
    // The host and registered drop view live for the controller's lifetime.
    // Insets leave room for the native glass rim instead of clipping it at the
    // borderless window's lower-right edge.
    let animate = panel.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      && screen.frame.contains(panel.frame.origin)
    if animate {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.18
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panel.animator().setFrame(target, display: true)
      }
    } else {
      panel.setFrame(target, display: true)
    }
    hosting.frame = dropView.bounds
    panel.orderFrontRegardless()
  }

  private func openCollection(forDrag: Bool) {
    guard !store.isExporting else { return }
    let state = AppState.shared
    state.switchShelf(to: .collection)
    if forDrag {
      openedForDrag = true
      state.appDelegate?.panel.isDragging = true
    }
    if state.popup.isClosed() { state.popup.open(height: state.popup.height) }
    if forDrag, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
       let shelf = state.appDelegate?.panel {
      let top = screen.frame.maxY - max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
      shelf.setFrameOrigin(NSPoint(x: screen.frame.midX - shelf.frame.width / 2, y: top - shelf.frame.height))
    }
    panel.orderOut(nil)
  }

  private func receivePromises(_ receivers: [NSFilePromiseReceiver]) {
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Clipio-Promises-\(UUID().uuidString)")
    do { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
    catch { store.lastError = error.localizedDescription; return }
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.qualityOfService = .utility
    for receiver in receivers {
      receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: queue) { [weak self] url, error in
        let image = Result { () throws -> CollectionImage in
          if let error { throw error }
          return try CollectionImage(contentsOf: url)
        }
        DispatchQueue.main.async {
          guard let self else { return }
          self.store.perform {
            try self.store.addImage(image.get())
          }
          try? FileManager.default.removeItem(at: url)
        }
      }
    }
  }
}

private struct CollectionEntryLabel: View {
  let dragging: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: dragging ? "tray.and.arrow.down.fill" : "tray")
          .foregroundStyle(dragging ? Color.accentColor : .primary)
        if dragging { Text("collection_drop_hint") }
      }
      .font(.system(size: dragging ? 13 : 11, weight: .medium))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .modifier(CollectionEntrySurface())
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .padding(4)
    .accessibilityLabel(Text(dragging ? "collection_drop_hint" : "collection_open"))
    .accessibilityIdentifier("collection-entry")
  }
}

private struct CollectionEntrySurface: ViewModifier {
  func body(content: Content) -> some View {
    content.background {
      Color.clear.modifier(ShelfGlassSurface(radius: 24))
    }
  }
}

private final class CollectionEntryDropView: NSView {
  var onEnter: (() -> Void)?
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
    onEnter?()
    return .copy
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
      onDrop?(urls.map { NSItemProvider(item: $0 as NSURL, typeIdentifier: UTType.fileURL.identifier) })
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
