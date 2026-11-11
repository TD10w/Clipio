import AppKit
import Foundation
import Darwin
import Observation

/// Collection metadata is independent of the clipboard database. Call mutations on the main thread.
@Observable
final class CollectionStore {
  static let shared = CollectionStore(
    directory: RuntimeEnvironment.isTesting
      ? FileManager.default.temporaryDirectory.appendingPathComponent("Clipio-tests-\(UUID().uuidString)")
      : URL.applicationSupportDirectory.appendingPathComponent("Clipio/Collection")
  )

  private(set) var items: [CollectionItem] = []
  private(set) var unavailableIDs: Set<UUID> = []
  var selectedIDs: Set<UUID> = []
  /// Stacks the user has opened. Session-only: Stacks come back collapsed after relaunch.
  var expandedBatches: Set<UUID> = []
  var searchQuery = "" {
    didSet { selectedIDs.formIntersection(Set(visibleItems.map(\.id))) }
  }
  var lastError: String?
  var importingCount = 0
  var isExporting = false
  var showClearConfirmation = false

  let directory: URL
  private let securityScoped: Bool
  private let writeManifest: (Data, URL) throws -> Void
  private var canWrite = true
  private let fileManager = FileManager.default
  @ObservationIgnored private var pendingMoves: [UUID: CollectionMoveObservation] = [:]

  private struct Manifest: Codable {
    let version: Int
    let items: [CollectionItem]
  }

  init(
    directory: URL,
    securityScoped: Bool = true,
    writeManifest: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
  ) {
    self.directory = directory
    self.securityScoped = securityScoped
    self.writeManifest = writeManifest
    pruneOldExports()
    let manifest = directory.appendingPathComponent("items.json")
    guard fileManager.fileExists(atPath: manifest.path) else { return }
    do {
      let saved = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifest))
      guard saved.version == 1 else { throw CollectionError.unreadableStore }
      // A manifest may never name a file outside its owned image directory.
      guard saved.items.allSatisfy({ item in
        item.ownedFileName.map { $0 == URL(fileURLWithPath: $0).lastPathComponent && !$0.hasPrefix(".") } ?? true
      }), Set(saved.items.map(\.id)).count == saved.items.count else {
        throw CollectionError.unreadableStore
      }
      items = saved.items
    } catch {
      canWrite = false
      lastError = CollectionError.unreadableStore.localizedDescription
    }
  }

  /// A search hit on any Stack member shows the whole Stack.
  var visibleItems: [CollectionItem] {
    guard !searchQuery.isEmpty else { return items }
    let matches = { (item: CollectionItem) in item.name.localizedCaseInsensitiveContains(self.searchQuery) }
    let matchedBatches = Set(items.filter(matches).compactMap(\.batchID))
    return items.filter { matches($0) || ($0.batchID.map(matchedBatches.contains) ?? false) }
  }

  /// Visible items grouped for display. A batch with fewer than two members left is
  /// shown as an ordinary card.
  var visibleEntries: [CollectionEntry] {
    let visible = visibleItems
    var members: [UUID: [CollectionItem]] = [:]
    for item in visible { if let batch = item.batchID { members[batch, default: []].append(item) } }
    var emitted: Set<UUID> = []
    var entries: [CollectionEntry] = []
    for item in visible {
      guard let batch = item.batchID, let group = members[batch], group.count > 1 else {
        entries.append(.single(item))
        continue
      }
      guard emitted.insert(batch).inserted else { continue }
      if expandedBatches.contains(batch) {
        entries.append(.collapseHandle(batch, group.count))
        entries.append(contentsOf: group.map(CollectionEntry.single))
      } else {
        entries.append(.stack(batch, group))
      }
    }
    return entries
  }

  func toggleExpanded(_ batch: UUID) {
    if !expandedBatches.insert(batch).inserted { expandedBatches.remove(batch) }
  }

  /// New items go first, except later members of a batch, which follow their batch so
  /// a Stack keeps the order it was dropped in.
  private func inserting(_ item: CollectionItem) -> [CollectionItem] {
    var updated = items
    if let batch = item.batchID, let last = updated.lastIndex(where: { $0.batchID == batch }) {
      updated.insert(item, at: last + 1)
    } else {
      updated.insert(item, at: 0)
    }
    return updated
  }

  @discardableResult
  func addFile(_ url: URL, batch: UUID? = nil) throws -> UUID {
    guard url.isFileURL else { throw CollectionError.invalidFile }
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    guard fileManager.isReadableFile(atPath: url.path) else { throw CollectionError.unavailable }
    if let existing = items.first(where: { item in
      item.ownedFileName == nil && (try? resolveURL(for: item.id).resolvingSymlinksInPath()) == url.resolvingSymlinksInPath()
    }) {
      return existing.id
    }
    let bookmark = try url.bookmarkData(
      options: securityScoped ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : [.minimalBookmark],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    let item = CollectionItem(
      id: UUID(), name: url.lastPathComponent, addedAt: Date(), isPinned: false,
      bookmark: bookmark, ownedFileName: nil, batchID: batch
    )
    try commit(inserting(item))
    return item.id
  }

  @discardableResult
  func addImage(data: Data, name: String) throws -> UUID {
    try addImage(CollectionImage(data: data, name: name))
  }

  @discardableResult
  func addImage(_ image: CollectionImage, batch: UUID? = nil) throws -> UUID {
    guard canWrite else { throw CollectionError.unreadableStore }
    let id = UUID()
    let fileName = "\(id.uuidString).\(image.fileExtension)"
    let images = directory.appendingPathComponent("Images")
    try fileManager.createDirectory(at: images, withIntermediateDirectories: true)
    let url = images.appendingPathComponent(fileName)
    try image.data.write(to: url, options: .atomic)
    let stem = URL(fileURLWithPath: image.name).deletingPathExtension().lastPathComponent
    let item = CollectionItem(
      id: id, name: (stem.isEmpty ? "Image" : stem) + "." + image.fileExtension, addedAt: Date(),
      isPinned: false, bookmark: nil, ownedFileName: fileName, batchID: batch
    )
    do {
      try commit(inserting(item))
    } catch {
      try? fileManager.removeItem(at: url)
      throw error
    }
    return id
  }

  func resolveURL(for id: UUID) throws -> URL {
    guard let item = items.first(where: { $0.id == id }) else { throw CollectionError.unavailable }
    let url: URL
    if let fileName = item.ownedFileName {
      url = directory.appendingPathComponent("Images").appendingPathComponent(fileName)
    } else if let bookmark = item.bookmark {
      var stale = false
      url = try URL(
        resolvingBookmarkData: bookmark,
        options: securityScoped ? [.withSecurityScope, .withoutUI] : [.withoutUI],
        relativeTo: nil, bookmarkDataIsStale: &stale
      )
      if stale {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var updated = items
        if let index = updated.firstIndex(where: { $0.id == id }) {
          updated[index].bookmark = try url.bookmarkData(
            options: securityScoped ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : [.minimalBookmark],
            includingResourceValuesForKeys: nil, relativeTo: nil
          )
          try commit(updated)
        }
      }
    } else {
      throw CollectionError.unavailable
    }
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    guard fileManager.isReadableFile(atPath: url.path) else { throw CollectionError.unavailable }
    return url
  }

  func refreshAvailability() {
    unavailableIDs = Set(items.compactMap { (try? resolveURL(for: $0.id)) == nil ? $0.id : nil })
  }

  func togglePin(_ id: UUID) throws {
    try togglePin(ids: [id])
  }

  /// Pins every item when any of them is unpinned, otherwise unpins them all, so a
  /// partly pinned selection or Stack never flips member by member.
  func togglePin(ids: Set<UUID>) throws {
    let indices = items.indices.filter { ids.contains(items[$0].id) }
    guard !indices.isEmpty else { return }
    let pin = indices.contains { !items[$0].isPinned }
    var updated = items
    for index in indices { updated[index].isPinned = pin }
    try commit(updated)
  }

  func remove(ids: Set<UUID>) throws {
    let removed = items.filter { ids.contains($0.id) }
    try commit(items.filter { !ids.contains($0.id) })
    for item in removed {
      if let fileName = item.ownedFileName {
        try? fileManager.removeItem(at: directory.appendingPathComponent("Images").appendingPathComponent(fileName))
      }
    }
  }

  func clearUnpinned() throws {
    try remove(ids: Set(items.filter { !$0.isPinned }.map(\.id)))
  }

  var outgoingDirectory: URL {
    RuntimeEnvironment.isTesting ? directory.appendingPathComponent("Outgoing")
      : fileManager.temporaryDirectory.appendingPathComponent("Clipio-Exports")
  }

  func pruneOldExports() {
    guard let files = try? fileManager.contentsOfDirectory(
      at: outgoingDirectory, includingPropertiesForKeys: [.contentModificationDateKey]
    ) else { return }
    for url in files {
      if let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
         Date().timeIntervalSince(modified) > 86400 {
        try? fileManager.removeItem(at: url)
      }
    }
  }

  func prepareExport(ids: Set<UUID>) throws -> CollectionExport {
    pruneOldExports()
    let selected = items.filter { ids.contains($0.id) }
    guard !selected.isEmpty else { throw CollectionError.unavailable }
    // AppKit negotiates one operation for the entire session. In a mixed move,
    // hand Finder copies of Pin items so their original files cannot be moved.
    let movesOriginals = selected.contains { !$0.isPinned && $0.ownedFileName == nil }
    var urls: [URL] = []
    var accessed: [URL] = []
    var stagedDirectories: [URL] = []
    do {
      let resolved = try selected.map { (item: $0, url: try resolveURL(for: $0.id)) }
      for entry in resolved {
        if entry.url.startAccessingSecurityScopedResource() { accessed.append(entry.url) }
      }
      let protectedURLs = items.filter { $0.isPinned && $0.ownedFileName == nil }.compactMap { item -> URL? in
        // Missing/unavailable pins cannot be handed to a destination, but shouldn't
        // prevent unrelated files from exporting.
        try? resolveURL(for: item.id)
      }
      // Moving a parent also moves descendants, even if a child is pinned. Reject
      // overlapping batches before staging or giving any URL to a destination.
      for parent in resolved where !parent.item.isPinned && parent.item.ownedFileName == nil {
        let prefix = parent.url.resolvingSymlinksInPath().path + "/"
        if resolved.contains(where: {
          $0.item.id != parent.item.id && $0.url.resolvingSymlinksInPath().path.hasPrefix(prefix)
        }) || protectedURLs.contains(where: { $0.resolvingSymlinksInPath().path.hasPrefix(prefix) }) {
          throw CollectionError.overlappingFiles
        }
      }
      for (item, url) in resolved {
        if item.ownedFileName != nil || (movesOriginals && item.isPinned) {
          // Destinations may read a file URL after ending the drag. Keep this outgoing
          // copy alive independently of clear/remove, and let macOS clean its temp storage.
          let outgoing = outgoingDirectory.appendingPathComponent(UUID().uuidString)
          try fileManager.createDirectory(at: outgoing, withIntermediateDirectories: true)
          stagedDirectories.append(outgoing)
          let staged = outgoing.appendingPathComponent(item.name)
          try fileManager.copyItem(at: url, to: staged)
          urls.append(staged)
        } else {
          urls.append(url)
        }
      }
      return CollectionExport(
        ids: Set(selected.map(\.id)), urls: urls, accessedURLs: accessed,
        // Dock Trash negotiates delete rather than move. Keep Pin batches out of
        // that negotiation: their originals must remain protected.
        operation: (movesOriginals ? NSDragOperation.move : .copy).union(
          selected.contains(where: \.isPinned) ? [] : .delete
        ),
        pinnedIDs: Set(selected.filter(\.isPinned).map(\.id)),
        exportedURLs: Dictionary(uniqueKeysWithValues: zip(selected.map(\.id), urls))
      )
    } catch {
      accessed.forEach { $0.stopAccessingSecurityScopedResource() }
      stagedDirectories.forEach { try? fileManager.removeItem(at: $0) }
      throw error
    }
  }

  func finishExport(_ export: CollectionExport, operation: NSDragOperation) throws {
    defer { export.endAccess() }
    let isTrash = operation == .delete && export.operation.contains(.delete)
    guard operation == .move || operation == .copy || isTrash else { return }
    var consumed: Set<UUID> = []
    for item in items where export.ids.contains(item.id) && !export.pinnedIDs.contains(item.id) && !item.isPinned {
      if operation == .move || isTrash, let source = export.exportedURLs[item.id] {
        if !fileManager.fileExists(atPath: source.path) {
          consumed.insert(item.id)
        } else {
          // Finder / Dock may return before completing a file operation.
          // Watch the source, with no idle polling, until it actually leaves.
          pendingMoves[item.id] = CollectionMoveObservation(url: source, onChange: { [weak self] in
            self?.reconcileMove(id: item.id, source: source)
          }, onExpire: { [weak self] in
            self?.pendingMoves[item.id] = nil
          })
          // Close the race between the existence check and installing the watch.
          if !fileManager.fileExists(atPath: source.path) { consumed.insert(item.id) }
        }
      } else if operation == .copy && item.ownedFileName != nil {
        consumed.insert(item.id)
      }
      // A copy callback must never consume an ordinary local reference.
    }
    if !consumed.isEmpty { try remove(ids: consumed) }
    refreshAvailability()
  }

  private func reconcileMove(id: UUID, source: URL) {
    guard !fileManager.fileExists(atPath: source.path) else { return }
    guard let item = items.first(where: { $0.id == id }), !item.isPinned else {
      pendingMoves[id] = nil
      return
    }
    // Only metadata / owned images are removed here. Never remove a local original.
    perform { try remove(ids: [id]) }
  }

  func select(_ id: UUID, extending: Bool) {
    if extending {
      if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) }
    } else {
      selectedIDs = [id]
    }
  }

  /// Keyboard moves step over shelf slots: a collapsed Stack is one stop.
  func moveSelection(by offset: Int) {
    let slots = visibleEntries.map(\.itemIDs).filter { !$0.isEmpty }
    guard !slots.isEmpty else { return }
    let current = slots.firstIndex { !$0.isDisjoint(with: selectedIDs) } ?? (offset > 0 ? -1 : slots.count)
    let next = min(max(current + offset, 0), slots.count - 1)
    selectedIDs = slots[next]
  }

  func selectEdge(last: Bool) {
    let slots = visibleEntries.map(\.itemIDs).filter { !$0.isEmpty }
    selectedIDs = (last ? slots.last : slots.first) ?? []
  }

  func perform(_ operation: () throws -> Void) {
    do { try operation() } catch { lastError = error.localizedDescription }
  }

  private func commit(_ updated: [CollectionItem]) throws {
    guard canWrite else { throw CollectionError.unreadableStore }
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(Manifest(version: 1, items: updated))
    try writeManifest(data, directory.appendingPathComponent("items.json"))
    items = updated
    pendingMoves = pendingMoves.filter { id, _ in updated.contains { $0.id == id && !$0.isPinned } }
    selectedIDs.formIntersection(Set(updated.map(\.id)))
    expandedBatches.formIntersection(Set(updated.compactMap(\.batchID)))
    unavailableIDs.formIntersection(Set(updated.map(\.id)))
  }
}

/// One event source per delayed move. Disappears with the store/item, without a
/// repeating timer. Scope stays alive until Finder completes or the item is removed.
private final class CollectionMoveObservation {
  private let source: DispatchSourceFileSystemObject
  private var expiry: DispatchWorkItem?

  init?(url: URL, onChange: @escaping () -> Void, onExpire: @escaping () -> Void) {
    let accessed = url.startAccessingSecurityScopedResource()
    let descriptor = open(url.path, O_EVTONLY)
    guard descriptor >= 0 else {
      if accessed { url.stopAccessingSecurityScopedResource() }
      return nil
    }
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: [.rename, .delete], queue: .main
    )
    source.setEventHandler(handler: onChange)
    source.setCancelHandler {
      Darwin.close(descriptor)
      if accessed { url.stopAccessingSecurityScopedResource() }
    }
    source.resume()
    // A receiver may report move for a no-op. Bound descriptor/scope retention;
    // if a transfer takes longer, keep its card rather than infer completion.
    let expiry = DispatchWorkItem(block: onExpire)
    self.expiry = expiry
    DispatchQueue.main.asyncAfter(deadline: .now() + 30 * 60, execute: expiry)
  }

  deinit {
    expiry?.cancel()
    source.cancel()
  }
}
