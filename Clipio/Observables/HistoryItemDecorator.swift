import AppKit.NSWorkspace
import Defaults
import Foundation
import Observation
import Sauce

@Observable
class HistoryItemDecorator: Identifiable, Hashable, HasVisibility {
  static func == (lhs: HistoryItemDecorator, rhs: HistoryItemDecorator) -> Bool {
    return lhs.id == rhs.id
  }

  // Bounding box for the hover-popup image. The popup is ~620x540pt, so ~2x that is
  // crisp on Retina; sizing to the full screen (the old behavior) kept near-full-res
  // copies of every hovered screenshot in memory for no visible benefit.
  static let previewImageSize = NSSize(width: 1280, height: 1120)
  static var thumbnailImageSize: NSSize { NSSize(width: 340, height: Defaults[.imageMaxHeight]) }

  let id = UUID()

  var title: String = ""
  var attributedTitle: AttributedString?

  var isVisible: Bool = true
  // The 1–9 quick-paste number shown on the card badge, set when shortcuts are assigned.
  var numericShortcut: Int?
  var selectionIndex: Int = -1
  var isSelected: Bool {
    return selectionIndex != -1
  }
  var shortcuts: [KeyShortcut] = []

  var application: String? {
    if item.universalClipboard {
      return "iCloud"
    }

    guard let bundle = item.application,
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
    else {
      return nil
    }

    return url.deletingPathExtension().lastPathComponent
  }

  var hasImage: Bool { item.hasImage }

  var previewImageGenerationTask: Task<(), Error>?
  var thumbnailImageGenerationTask: Task<(), Error>?
  var previewImage: NSImage?
  var thumbnailImage: NSImage?
  var applicationImage: ApplicationImage

  // 10k characters seems to be more than enough on large displays.
  // Cached: previewableText can parse HTML/RTF via NSAttributedString, which is an
  // expensive main-thread XPC call. The item's content is immutable once stored, so
  // resolve it at most once per decorator instead of on every SwiftUI body access
  // (recomputing it per render/hover was blocking the main thread → beachball).
  // @ObservationIgnored so writing the cache from the getter can't perturb a render pass.
  @ObservationIgnored private var cachedText: String?
  var text: String {
    if let cachedText { return cachedText }
    let resolved = item.previewableText.shortened(to: 10_000)
    cachedText = resolved
    return resolved
  }

  var isPinned: Bool { item.pin != nil }
  var isUnpinned: Bool { item.pin == nil }

  func hash(into hasher: inout Hasher) {
    // We need to hash title and attributedTitle, so SwiftUI knows it needs to update the view if they chage
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(attributedTitle)
  }

  private(set) var item: HistoryItem

  init(_ item: HistoryItem, shortcuts: [KeyShortcut] = []) {
    self.item = item
    self.shortcuts = shortcuts
    self.title = item.title
    self.applicationImage = ApplicationImageCache.shared.getImage(item: item)

    synchronizeItemPin()
    synchronizeItemTitle()
  }

  @MainActor
  func ensureThumbnailImage() {
    guard item.hasImage else {
      return
    }
    guard thumbnailImage == nil else {
      return
    }
    guard thumbnailImageGenerationTask == nil else {
      return
    }
    guard let data = item.imageData else {
      return
    }
    let size = Self.thumbnailImageSize
    thumbnailImageGenerationTask = Task.detached(priority: .userInitiated) { [weak self] in
      guard let image = NSImage(data: data) else { return }
      let resized = image.resized(to: size)
      _ = resized.cgImage(forProposedRect: nil, context: nil, hints: nil)
      await MainActor.run { [weak self] in
        self?.thumbnailImage = resized
      }
    }
  }

  @MainActor
  func ensurePreviewImage() {
    guard item.hasImage else {
      return
    }
    guard previewImage == nil else {
      return
    }
    guard previewImageGenerationTask == nil else {
      return
    }
    guard let data = item.imageData else {
      return
    }
    let size = Self.previewImageSize
    previewImageGenerationTask = Task.detached(priority: .userInitiated) { [weak self] in
      guard let image = NSImage(data: data) else { return }
      let resized = image.resized(to: size)
      _ = resized.cgImage(forProposedRect: nil, context: nil, hints: nil)
      await MainActor.run { [weak self] in
        self?.previewImage = resized
      }
    }
  }

  @MainActor
  func asyncGetPreviewImage() async -> NSImage? {
    if let image = previewImage {
      return image
    }
    ensurePreviewImage()
    _ = await previewImageGenerationTask?.result
    return previewImage
  }

  // Free just the large preview image while keeping the small thumbnail the card
  // still shows. Called when the hover popup hides, so screen-scale previews don't
  // pile up in memory as the user hovers across many image clips. Runs on the main
  // thread (invoked from the popup's hide handlers).
  func releasePreviewImage() {
    previewImageGenerationTask?.cancel()
    previewImageGenerationTask = nil
    previewImage?.recache()
    previewImage = nil
  }

  @MainActor
  func cleanupImages() {
    thumbnailImageGenerationTask?.cancel()
    previewImageGenerationTask?.cancel()
    thumbnailImage?.recache()
    previewImage?.recache()
    thumbnailImage = nil
    previewImage = nil
  }

  @MainActor
  private func generateThumbnailImage() {
    guard item.hasImage else {
      return
    }
    guard let data = item.imageData else {
      return
    }
    guard let image = NSImage(data: data) else {
      return
    }
    thumbnailImage = image.resized(to: HistoryItemDecorator.thumbnailImageSize)
  }

  @MainActor
  private func generatePreviewImage() {
    guard item.hasImage else {
      return
    }
    guard let data = item.imageData else {
      return
    }
    guard let image = NSImage(data: data) else {
      return
    }
    previewImage = image.resized(to: HistoryItemDecorator.previewImageSize)
  }

  @MainActor
  func sizeImages() {
    generatePreviewImage()
    generateThumbnailImage()
  }

  func highlight(_ query: String, _ ranges: [Range<String.Index>]) {
    guard !query.isEmpty, !title.isEmpty else {
      attributedTitle = nil
      return
    }

    var attributedString = AttributedString(title.shortened(to: 500))
    for range in ranges {
      if let lowerBound = AttributedString.Index(range.lowerBound, within: attributedString),
         let upperBound = AttributedString.Index(range.upperBound, within: attributedString) {
        switch Defaults[.highlightMatch] {
        case .bold:
          attributedString[lowerBound..<upperBound].font = .bold(.body)()
        case .italic:
          attributedString[lowerBound..<upperBound].font = .italic(.body)()
        case .underline:
          attributedString[lowerBound..<upperBound].underlineStyle = .single
        default:
          attributedString[lowerBound..<upperBound].backgroundColor = .findHighlightColor
          attributedString[lowerBound..<upperBound].foregroundColor = .black
        }
      }
    }

    attributedTitle = attributedString
  }

  @MainActor
  func togglePin() {
    if item.pin != nil {
      item.pin = nil
    } else {
      let pin = HistoryItem.randomAvailablePin
      item.pin = pin
    }
  }

  private func synchronizeItemPin() {
    _ = withObservationTracking {
      item.pin
    } onChange: {
      DispatchQueue.main.async {
        self.synchronizeItemPin()
      }
    }
  }

  private func synchronizeItemTitle() {
    _ = withObservationTracking {
      item.title
    } onChange: {
      DispatchQueue.main.async {
        self.title = self.item.title
        self.synchronizeItemTitle()
      }
    }
  }
}
