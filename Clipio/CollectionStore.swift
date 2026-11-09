import AppKit
import Foundation
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

  var visibleItems: [CollectionItem] {
    items.filter { searchQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(searchQuery) }
  }

  @discardableResult
  func addFile(_ url: URL) throws -> UUID {
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
      bookmark: bookmark, ownedFileName: nil
    )
    try commit([item] + items)
    return item.id
  }

  @discardableResult
  func addImage(data: Data, name: String) throws -> UUID {
    try addImage(CollectionImage(data: data, name: name))
  }

  @discardableResult
  func addImage(_ image: CollectionImage) throws -> UUID {
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
      isPinned: false, bookmark: nil, ownedFileName: fileName
    )
    do {
      try commit([item] + items)
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

  func togglePin(ids: Set<UUID>) throws {
    let indices = items.indices.filter { ids.contains(items[$0].id) }
    guard !indices.isEmpty else { return }
    var updated = items
    for index in indices { updated[index].isPinned.toggle() }
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
    var urls: [URL] = []
    var accessed: [URL] = []
    do {
      for item in selected {
        let url = try resolveURL(for: item.id)
        if url.startAccessingSecurityScopedResource() { accessed.append(url) }
        if item.ownedFileName != nil {
          // Destinations may read a file URL after ending the drag. Keep this outgoing
          // copy alive independently of clear/remove, and let macOS clean its temp storage.
          let outgoing = outgoingDirectory.appendingPathComponent(UUID().uuidString)
          try fileManager.createDirectory(at: outgoing, withIntermediateDirectories: true)
          let staged = outgoing.appendingPathComponent(item.name)
          try fileManager.copyItem(at: url, to: staged)
          urls.append(staged)
        } else {
          urls.append(url)
        }
      }
      return CollectionExport(ids: Set(selected.map(\.id)), urls: urls, accessedURLs: accessed)
    } catch {
      accessed.forEach { $0.stopAccessingSecurityScopedResource() }
      throw error
    }
  }

  func finishExport(_ export: CollectionExport, accepted: Bool) throws {
    defer { export.endAccess() }
    guard accepted else { return }
    let consumed = Set(items.filter { export.ids.contains($0.id) && !$0.isPinned }.map(\.id))
    try remove(ids: consumed)
  }

  func select(_ id: UUID, extending: Bool) {
    if extending {
      if !selectedIDs.insert(id).inserted { selectedIDs.remove(id) }
    } else {
      selectedIDs = [id]
    }
  }

  func moveSelection(by offset: Int) {
    let visible = visibleItems
    guard !visible.isEmpty else { return }
    let current = visible.firstIndex { selectedIDs.contains($0.id) } ?? (offset > 0 ? -1 : visible.count)
    let next = min(max(current + offset, 0), visible.count - 1)
    selectedIDs = [visible[next].id]
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
    selectedIDs.formIntersection(Set(updated.map(\.id)))
    unavailableIDs.formIntersection(Set(updated.map(\.id)))
  }
}
