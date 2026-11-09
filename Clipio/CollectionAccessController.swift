import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// A small entry beside the notch. It never becomes key; the existing shelf owns all editing.
@MainActor
final class CollectionAccessController {
  private let store: CollectionStore
  private let panel: NSPanel
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
    monitors.forEach(NSEvent.removeMonitor)
    if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    let entryPanel = panel
    Task { @MainActor in entryPanel.orderOut(nil) }
  }

  private func observeCount() {
    withObservationTracking {
      _ = store.items.count
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
      dragChangeCount = dragPasteboard.changeCount
    case .leftMouseDragged:
      guard !store.isExporting, dragPasteboard.changeCount != dragChangeCount,
            dragPasteboard.types?.contains(where: { type in
              type == .fileURL || type == .png || type == .tiff || type == .URL
                || NSFilePromiseReceiver.readableDraggedTypes.contains(type.rawValue)
            }) == true else { return }
      if !showingDrag { showingDrag = true; updateEntry() }
    case .leftMouseUp:
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        guard let self else { return }
        self.showingDrag = false
        if self.openedForDrag {
          AppState.shared.appDelegate?.panel.isDragging = false
          self.openedForDrag = false
        }
        self.updateEntry()
      }
    default: break
    }
  }

  private func updateEntry() {
    guard showingDrag || !store.items.isEmpty else { panel.orderOut(nil); return }
    let screen = (showingDrag ? NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } : NSScreen.main)
      ?? NSScreen.main
    guard let screen else { return }
    let height: CGFloat = 26
    let width: CGFloat = showingDrag ? 146 : 56
    let notchRight = screen.auxiliaryTopRightArea?.minX ?? (screen.frame.midX + 80)
    let topInset = max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
    panel.setFrame(NSRect(
      x: min(notchRight + 6, screen.frame.maxX - width - 12),
      y: screen.frame.maxY - topInset + (topInset - height) / 2,
      width: width, height: height
    ), display: true)
    let content = CollectionEntryDropView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    let hosting = NSHostingView(rootView: CollectionEntryLabel(count: store.items.count, dragging: showingDrag) { [weak self] in
      self?.openCollection(forDrag: false)
    })
    hosting.frame = content.bounds
    hosting.autoresizingMask = [.width, .height]
    content.addSubview(hosting)
    content.onEnter = { [weak self] in self?.openCollection(forDrag: true) }
    content.onDrop = { [weak self] providers in
      guard let self, !self.store.isExporting else { return }
      Task { await CollectionImporter.collect(providers, into: self.store) }
    }
    content.onPromises = { [weak self] receivers in
      guard let self else { return }
      self.receivePromises(receivers)
    }
    panel.contentView = content
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
  }

  private func receivePromises(_ receivers: [NSFilePromiseReceiver]) {
    let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Clipio-Promises-\(UUID().uuidString)")
    do { try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true) }
    catch { store.lastError = error.localizedDescription; return }
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    for receiver in receivers {
      receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: queue) { [weak self] url, error in
        let data = try? Data(contentsOf: url)
        DispatchQueue.main.async {
          guard let self else { return }
          self.store.perform {
            if let error { throw error }
            guard let data else { throw CollectionError.invalidImage }
            try self.store.addImage(data: data, name: url.lastPathComponent)
          }
          try? FileManager.default.removeItem(at: url)
        }
      }
    }
  }
}

private struct CollectionEntryLabel: View {
  let count: Int
  let dragging: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Image(systemName: "tray")
        if dragging { Text("collection_drop_hint") }
        else { Text(count, format: .number) }
      }
      .font(.system(size: 11, weight: .medium))
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.regularMaterial, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text("collection_open"))
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
