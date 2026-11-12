import AppKit.NSImage
import ImageIO

// Based on https://stackoverflow.com/questions/73062803/resizing-nsimage-keeping-aspect-ratio-reducing-the-image-size-while-trying-to-sc.
extension NSImage {
  func resized(to newSize: NSSize) -> NSImage {
    let ratioX = newSize.width / size.width
    let ratioY = newSize.height / size.height
    let ratio = ratioX < ratioY ? ratioX : ratioY
    let newHeight = size.height * ratio
    let newWidth = size.width * ratio
    let newSize = NSSize(width: newWidth, height: newHeight)

    // Don't attempt to size up.
    if newSize.height >= size.height {
      return self
    }

    return NSImage(size: newSize, flipped: false) { destRect in
      if let context = NSGraphicsContext.current {
        context.imageInterpolation = .high
        self.draw(in: destRect, from: NSRect.zero, operation: .copy, fraction: 1)
      }

      return true
    }
  }
}

extension NSImage {
  static func downsampled(data: Data, maxPixelSize: Int) -> NSImage? {
    guard maxPixelSize > 0,
          let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
          ] as CFDictionary) else { return nil }
    return NSImage(cgImage: image, size: .zero)
  }
  static func downsampled(data: Data, fitting bounds: NSSize) -> NSImage? {
    guard let sourceSize = NSImage(data: data)?.size, sourceSize.width > 0, sourceSize.height > 0,
          bounds.width > 0, bounds.height > 0 else { return nil }
    let scale = min(1, min(bounds.width / sourceSize.width, bounds.height / sourceSize.height))
    let size = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    guard let image = downsampled(data: data, maxPixelSize: Int(ceil(max(size.width, size.height) * 2))) else { return nil }
    image.size = size
    return image
  }

}
