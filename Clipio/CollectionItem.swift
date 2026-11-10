import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CollectionItem: Codable, Identifiable, Equatable {
  let id: UUID
  let name: String
  let addedAt: Date
  var isPinned: Bool
  var bookmark: Data?
  let ownedFileName: String?
}

/// Validated image bytes, prepared off the UI thread for browser imports.
struct CollectionImage: Sendable {
  static let maximumByteCount = 64 * 1024 * 1024
  let data: Data
  let name: String
  let fileExtension: String

  init(data: Data, name: String) throws {
    guard data.count <= Self.maximumByteCount,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) > 0,
          let type = CGImageSourceGetType(source),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 16384, height <= 16384,
          width * height <= 64_000_000 else { throw CollectionError.invalidImage }
    self.data = data
    self.name = name
    fileExtension = UTType(type as String)?.preferredFilenameExtension ?? "png"
  }

  init(contentsOf url: URL) throws {
    let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard values.isRegularFile == true, let size = values.fileSize,
          size >= 0, size <= Self.maximumByteCount else { throw CollectionError.invalidImage }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var data = Data()
    data.reserveCapacity(size)
    while let chunk = try handle.read(upToCount: min(1024 * 1024, Self.maximumByteCount - data.count + 1)),
          !chunk.isEmpty {
      guard chunk.count <= Self.maximumByteCount - data.count else { throw CollectionError.invalidImage }
      data.append(chunk)
    }
    try self.init(data: data, name: url.lastPathComponent)
  }
}

struct CollectionExport {
  let ids: Set<UUID>
  let urls: [URL]
  let accessedURLs: [URL]
  let operation: NSDragOperation
  let originalURLs: [UUID: URL]
  let pinnedIDs: Set<UUID>

  func endAccess() {
    accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
  }
}

enum CollectionError: LocalizedError {
  case unavailable, invalidImage, invalidFile, unreadableStore, unsupportedDrop

  var errorDescription: String? {
    let key: String
    switch self {
    case .unavailable: key = "collection_file_unavailable"
    case .invalidImage: key = "collection_invalid_image"
    case .invalidFile: key = "collection_invalid_file"
    case .unreadableStore: key = "collection_store_unavailable"
    case .unsupportedDrop: key = "collection_unsupported_drop"
    }
    return NSLocalizedString(key, comment: "")
  }
}

enum ShelfMode {
  case clipboard, collection

  var other: ShelfMode { self == .clipboard ? .collection : .clipboard }
  var symbol: String { self == .clipboard ? "clipboard" : "tray" }
}
