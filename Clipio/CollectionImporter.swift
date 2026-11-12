import AppKit
import UniformTypeIdentifiers

/// Retains the original drag URLs and their grants across asynchronous loading.
final class CollectionFileDrop {
  let urls: [URL]
  private let accessed: [URL]
  init(urls: [URL]) {
    self.urls = urls
    accessed = urls.filter { $0.startAccessingSecurityScopedResource() }
  }
  deinit { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }
}

@MainActor
final class CollectionImportBatch {
  private let store: CollectionStore
  private let existingIDs: Set<UUID>
  private var remaining: Int
  private var receivedIDs: Set<UUID> = []
  private var failures = 0
  private var lastError: Error?

  init(count: Int, store: CollectionStore) {
    self.store = store
    existingIDs = Set(store.items.map(\.id))
    remaining = max(0, count)
    store.importingCount += remaining
  }

  func complete(id: UUID? = nil, error: Error? = nil) {
    guard remaining > 0 else { return }
    if let error {
      failures += 1
      lastError = error
    } else if let id, !existingIDs.contains(id) {
      receivedIDs.insert(id)
    }
    remaining -= 1
    store.importingCount -= 1
    guard remaining == 0 else { return }
    if failures > 0 {
      store.lastError = String(format: NSLocalizedString("collection_import_failed", comment: ""), failures)
        + "\n" + (lastError?.localizedDescription ?? "")
    } else if !receivedIDs.isDisjoint(with: Set(store.items.map(\.id))) {
      store.recordReceipt()
    }
    store.refreshAvailability()
  }
}

@MainActor
enum CollectionImporter {
  static let supportedTypes: [UTType] = [.fileURL, .image, .url, .plainText]

  static func collect(_ providers: [NSItemProvider], into store: CollectionStore) async {
    let receipt = CollectionImportBatch(count: providers.count, store: store)
    // Everything delivered by one drop forms one Stack.
    let batch = providers.count > 1 ? UUID() : nil
    for provider in providers {
      do {
        let id: UUID?
        if let file = await loadURL(from: provider, type: UTType.fileURL.identifier), file.isFileURL {
          id = try await addFile(file, provider: provider, batch: batch, into: store)
        } else if let image = await imageData(from: provider) {
          let name = provider.suggestedName ?? "Image"
          let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: image, name: name) }.value
          id = try store.addImage(prepared, batch: batch)
        } else if let url = await loadURL(from: provider, type: UTType.url.identifier) {
          if url.isFileURL {
            id = try addNewFile(url, batch: batch, into: store)
          } else {
            if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
              let data = try await downloadImage(url)
              let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: data, name: url.lastPathComponent) }.value
              id = try store.addImage(prepared, batch: batch)
            } else {
              id = try store.addLink(url, batch: batch)
            }
          }
        } else if let text = await loadText(from: provider) {
          id = try store.addText(text, batch: batch)
        } else {
          throw CollectionError.unsupportedDrop
        }
        receipt.complete(id: id)
      } catch {
        receipt.complete(error: error)
      }
    }
  }

  static func collectFiles(_ drop: CollectionFileDrop, fallbacks: [NSItemProvider], into store: CollectionStore) async {
    defer { withExtendedLifetime(drop) {} }
    let receipt = CollectionImportBatch(count: drop.urls.count, store: store)
    let batch = drop.urls.count > 1 ? UUID() : nil
    for (index, url) in drop.urls.enumerated() {
      do {
        let provider = index < fallbacks.count ? fallbacks[index] : NSItemProvider()
        let id = try await addFile(url, provider: provider, batch: batch, into: store)
        receipt.complete(id: id)
      } catch { receipt.complete(error: error) }
    }
  }

  static func collectPromises(_ receivers: [NSFilePromiseReceiver], into store: CollectionStore) {
    guard !receivers.isEmpty else { return }
    // Receivers expose names/types but no reliable size or cancellation budget.
    // The direct URL/image/text representations are tried before reaching here.
    store.lastError = CollectionError.virtualMediaNeedsFile.localizedDescription
  }

  static func accepts(types: [NSPasteboard.PasteboardType]) -> Bool {
    types.contains { type in
      if type == NSPasteboard.PasteboardType("NSFilenamesPboardType") { return true }
      if NSFilePromiseReceiver.readableDraggedTypes.contains(type.rawValue) { return true }
      guard let value = UTType(type.rawValue) else { return false }
      return supportedTypes.contains { value.conforms(to: $0) }
    }
  }

  static func referenceOperation(offered: NSDragOperation) -> NSDragOperation {
    if offered.contains(.copy) { return .copy }
    if offered.contains(.link) { return .link }
    if offered.contains(.generic) { return .generic }
    return []
  }

  /// Apps like Messages drag a URL into their own private storage alongside the image
  /// bytes. Such a URL is unreadable from the sandbox, and referencing it would let a
  /// later drag-out move the file out of that app's storage. Keep a copy of the bytes
  /// instead; ordinary user files stay references.
  private static func addFile(_ file: URL, provider: NSItemProvider, batch: UUID?, into store: CollectionStore) async throws -> UUID? {
    if !isAppPrivate(file) {
      do {
        return try addNewFile(file, batch: batch, into: store)
      } catch {
        guard let image = await imageData(from: provider) else { throw error }
        return try await addOwnedImage(image, name: file.lastPathComponent, batch: batch, into: store)
      }
    }
    guard let image = await imageData(from: provider) else { throw CollectionError.unavailable }
    return try await addOwnedImage(image, name: file.lastPathComponent, batch: batch, into: store)
  }

  // No suspension between checking and adding: concurrent drops cannot claim
  // each other's persisted item as a new insertion.
  private static func addNewFile(_ file: URL, batch: UUID?, into store: CollectionStore) throws -> UUID? {
    let count = store.items.count
    let id = try store.addFile(file, batch: batch)
    return store.items.count > count ? id : nil
  }

  private static func addOwnedImage(_ data: Data, name: String, batch: UUID?, into store: CollectionStore) async throws -> UUID {
    let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: data, name: name) }.value
    return try store.addImage(prepared, batch: batch)
  }

  /// Home whose ~/Library counts as app-private. Tests point it at a scratch folder.
  static var appPrivateHome = realHomeDirectory

  /// Inside the real user's ~/Library (Messages, Mail, other apps' containers…): places
  /// that belong to an app, not to the user's documents.
  static func isAppPrivate(_ url: URL, home: String? = nil) -> Bool {
    let home = URL(fileURLWithPath: home ?? appPrivateHome).resolvingSymlinksInPath().path
    let path = url.standardizedFileURL.resolvingSymlinksInPath().path
    return path.hasPrefix(home + "/Library/")
  }

  /// The user's actual home, not the sandbox container that NSHomeDirectory() reports.
  nonisolated static var realHomeDirectory: String {
    if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir { return String(cString: dir) }
    return NSHomeDirectory()
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

  private static func loadText(from provider: NSItemProvider) async -> String? {
    let types = provider.registeredTypeIdentifiers.filter { UTType($0)?.conforms(to: .plainText) == true }
    guard let type = types.first(where: { $0 == UTType.utf8PlainText.identifier }) ?? types.first else { return nil }
    return await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
        if let text = item as? String {
          continuation.resume(returning: text.utf8.count <= CollectionStore.maximumTextBytes ? text : nil)
          return
        }
        guard let data = item as? Data, data.count <= CollectionStore.maximumTextBytes * 2 + 4 else {
          continuation.resume(returning: nil)
          return
        }
        let encoding: String.Encoding
        let hasUTF16BOM = data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff])
        if hasUTF16BOM { encoding = .utf16 }
        else if type.contains("utf16") { encoding = .utf16LittleEndian }
        else { encoding = .utf8 }
        let text = String(data: data, encoding: encoding)
        continuation.resume(returning: text.flatMap { $0.utf8.count <= CollectionStore.maximumTextBytes ? $0 : nil })
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
        continuation.resume(returning: url.flatMap { try? CollectionImage(contentsOf: $0).data })
      }
    }
  }

  nonisolated static func downloadImage(
    _ url: URL,
    configuration: URLSessionConfiguration = .ephemeral,
    maximumBytes: Int = CollectionImage.maximumByteCount
  ) async throws -> Data {
    guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
      throw CollectionError.unsupportedDrop
    }
    guard maximumBytes > 0, maximumBytes <= CollectionImage.maximumByteCount else {
      throw CollectionError.invalidImage
    }
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60
    configuration.urlCache = nil
    return try await CollectionImageDownload(configuration: configuration, maximumBytes: maximumBytes).load(url)
  }
}

// Response/data callbacks are serialized. The lock protects task setup and cancellation.
private final class CollectionImageDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let configuration: URLSessionConfiguration
  private let maximumBytes: Int
  private let lock = NSLock()
  private var session: URLSession?
  private var task: URLSessionDataTask?
  private var continuation: CheckedContinuation<Data, Error>?
  private var cancelled = false
  private var received = Data()
  private var acceptedResponse = false
  private var failure: Error?

  init(configuration: URLSessionConfiguration, maximumBytes: Int) {
    self.configuration = configuration
    self.maximumBytes = maximumBytes
    super.init()
  }

  func load(_ url: URL) async throws -> Data {
    defer { session?.invalidateAndCancel() }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        guard !cancelled else {
          lock.unlock()
          continuation.resume(throwing: CancellationError())
          return
        }
        self.continuation = continuation
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        self.session = session
        let task = session.dataTask(with: url)
        self.task = task
        lock.unlock()
        task.resume()
      }
    } onCancel: {
      self.cancel()
    }
  }

  private func cancel() {
    lock.lock()
    cancelled = true
    let task = task
    lock.unlock()
    task?.cancel()
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    guard let response = response as? HTTPURLResponse,
          (200..<300).contains(response.statusCode),
          response.mimeType?.lowercased().hasPrefix("image/") == true,
          response.expectedContentLength <= Int64(maximumBytes),
          (response.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init) ?? -1) <= Int64(maximumBytes) else {
      failure = CollectionError.invalidImage
      completionHandler(.cancel)
      return
    }
    acceptedResponse = true
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard failure == nil else { return }
    guard data.count <= maximumBytes - received.count else {
      failure = CollectionError.invalidImage
      dataTask.cancel()
      return
    }
    received.append(data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let result: Result<Data, Error>
    if let error = failure ?? error { result = .failure(error) }
    else if acceptedResponse { result = .success(received) }
    else { result = .failure(CollectionError.invalidImage) }
    lock.lock()
    let continuation = continuation
    self.continuation = nil
    self.task = nil
    lock.unlock()
    continuation?.resume(with: result)
  }
}
