import AppKit
import SwiftHEXColors
import SwiftUI

struct CardItemView: View {
  let item: HistoryItemDecorator
  let onSelect: () -> Void

  @State private var isHovered = false

  static let cardWidth: CGFloat = 130
  static let cardHeight: CGFloat = 140
  private static let footerHeight: CGFloat = 26

  private var timeString: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: item.item.lastCopiedAt, relativeTo: Date())
  }

  private var detectedColor: NSColor? {
    NSColor(hexString: item.title)
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      cardContent
      cardFooter
    }
    .frame(width: Self.cardWidth, height: Self.cardHeight)
    .background(isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          isHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.14),
          lineWidth: 0.5
        )
    )
    .onHover { isHovered = $0 }
    .onTapGesture { onSelect() }
    .onDrag {
      dragProvider()
    } preview: {
      dragPreview()
    }
    .onAppear {
      item.ensureThumbnailImage()
    }
  }

  @ViewBuilder
  private var cardContent: some View {
    if let image = item.thumbnailImage {
      imageCard(image: image)
    } else if let color = detectedColor {
      colorCard(color: color)
    } else {
      textCard
    }
  }

  @ViewBuilder
  private func imageCard(image: NSImage) -> some View {
    Image(nsImage: image)
      .resizable()
      .scaledToFill()
      .frame(width: Self.cardWidth, height: Self.cardHeight - Self.footerHeight)
      .clipped()
      .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private func colorCard(color: NSColor) -> some View {
    VStack(spacing: 0) {
      Color(nsColor: color)
        .frame(height: Self.cardHeight - Self.footerHeight - 26)
      Text(item.title)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .frame(height: 26, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.4))
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var textCard: some View {
    Text(item.text)
      .font(.system(size: 11))
      .foregroundStyle(.white.opacity(0.85))
      .lineLimit(6)
      .multilineTextAlignment(.leading)
      .padding(.horizontal, 8)
      .padding(.top, 8)
      .padding(.bottom, Self.footerHeight + 4)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var cardFooter: some View {
    HStack(spacing: 4) {
      AppImageView(appImage: item.applicationImage, size: NSSize(width: 13, height: 13))
      Text(timeString)
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.5))
        .lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 7)
    .frame(height: Self.footerHeight)
    .background(.black.opacity(0.3))
  }

  private func dragProvider() -> NSItemProvider {
    if let panel = NSApp.windows.compactMap({ $0 as? FloatingPanel<ContentView> }).first {
      panel.isDragging = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        panel.isDragging = false
      }
    }

    if let image = item.thumbnailImage {
      return NSItemProvider(object: image)
    }
    return NSItemProvider(object: item.text as NSString)
  }

  @ViewBuilder
  private func dragPreview() -> some View {
    if let image = item.thumbnailImage {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: 200, maxHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } else {
      Text(item.text)
        .font(.system(size: 12))
        .lineLimit(4)
        .padding(10)
        .frame(maxWidth: 200, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}
