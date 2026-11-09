import AppKit
import UniformTypeIdentifiers

@MainActor
enum CollectionImporter {
  static let supportedTypes: [UTType] = [.fileURL, .image, .url]

  static func collect(_ providers: [NSItemProvider], into store: CollectionStore) async {
    store.importingCount += providers.count
    var failures = 0
    for provider in providers {
      do {
        if let file = await loadURL(from: provider, type: UTType.fileURL.identifier), file.isFileURL {
          try store.addFile(file)
        } else if let image = await imageData(from: provider) {
          let name = provider.suggestedName ?? "Image"
          let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: image, name: name) }.value
          try store.addImage(prepared)
        } else if let url = await loadURL(from: provider, type: UTType.url.identifier) {
          if url.isFileURL {
            try store.addFile(url)
          } else {
            let data = try await downloadImage(url)
            let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: data, name: url.lastPathComponent) }.value
            try store.addImage(prepared)
          }
        } else {
          throw CollectionError.unsupportedDrop
        }
      } catch {
        failures += 1
        store.lastError = error.localizedDescription
      }
      store.importingCount -= 1
    }
    if failures > 0 {
      store.lastError = String(format: NSLocalizedString("collection_import_failed", comment: ""), failures)
        + "\n" + (store.lastError ?? "")
    }
    store.refreshAvailability()
  }

  private static func loadURL(from provider: NSItemProvider, type: String) async -> URL? {
    guard provider.hasItemConformingToTypeIdentifier(type) else { return nil }
    return await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
        let url: URL?
        switch item {
        case let value as URL: url = value
        case let value as Data: url = URL(dataRepresentation: value, relativeTo: nil)
        case let value as String: url = URL(string: value)
        default: url = nil
        }
        continuation.resume(returning: url)
      }
    }
  }

  private static func imageData(from provider: NSItemProvider) async -> Data? {
    guard let type = provider.registeredTypeIdentifiers.first(where: {
      UTType($0)?.conforms(to: .image) == true
    }) else { return nil }
    let data: Data? = await withCheckedContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
        continuation.resume(returning: data)
      }
    }
    if let data { return data }
    // Browser file promises can expose their image only as a temporary file. Read it
    // inside the callback, before NSItemProvider revokes that temporary URL.
    return await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
        continuation.resume(returning: url.flatMap { try? Data(contentsOf: $0) })
      }
    }
  }

  private static func downloadImage(_ url: URL) async throws -> Data {
    guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
      throw CollectionError.unsupportedDrop
    }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 30
    let session = URLSession(configuration: configuration)
    defer { session.finishTasksAndInvalidate() }
    let (file, response) = try await session.download(from: url)
    defer { try? FileManager.default.removeItem(at: file) }
    guard let response = response as? HTTPURLResponse,
          (200..<300).contains(response.statusCode),
          response.mimeType?.hasPrefix("image/") == true,
          let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
          size <= 64 * 1024 * 1024 else {
      throw CollectionError.invalidImage
    }
    return try Data(contentsOf: file)
  }
}
