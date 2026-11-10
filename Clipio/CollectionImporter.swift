import AppKit
import UniformTypeIdentifiers

@MainActor
enum CollectionImporter {
  static let supportedTypes: [UTType] = [.fileURL, .image, .url]

  static func collect(_ providers: [NSItemProvider], into store: CollectionStore) async {
    store.importingCount += providers.count
    var failures = 0
    // Everything delivered by one drop forms one Stack.
    let batch = providers.count > 1 ? UUID() : nil
    for provider in providers {
      do {
        if let file = await loadURL(from: provider, type: UTType.fileURL.identifier), file.isFileURL {
          try store.addFile(file, batch: batch)
        } else if let image = await imageData(from: provider) {
          let name = provider.suggestedName ?? "Image"
          let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: image, name: name) }.value
          try store.addImage(prepared, batch: batch)
        } else if let url = await loadURL(from: provider, type: UTType.url.identifier) {
          if url.isFileURL {
            try store.addFile(url, batch: batch)
          } else {
            let data = try await downloadImage(url)
            let prepared = try await Task.detached(priority: .utility) { try CollectionImage(data: data, name: url.lastPathComponent) }.value
            try store.addImage(prepared, batch: batch)
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
