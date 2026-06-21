import AppKit
import SwiftHEXColors
import SwiftUI
import UniformTypeIdentifiers

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
    .overlay(alignment: .topLeading) {
      if let key = item.shortcuts.first?.description.last {
        Text(String(key))
          .font(.system(size: 10, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.9))
          .frame(width: 16, height: 16)
          .background(Color.black.opacity(0.45))
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .padding(5)
      }
    }
    .overlay(alignment: .topTrailing) {
      if item.isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 9))
          .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.47))
          .padding(5)
      }
    }
    .onHover { hovering in
      isHovered = hovering
      if hovering {
        AppState.shared.appDelegate?.showPreview(for: item)
      } else {
        AppState.shared.appDelegate?.hidePreviewSoon(for: item)
      }
    }
    .hoverSelectionId(item.id)
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
    // Keep the panel open while the drag is in flight, otherwise resignKey closes it
    // and cancels the drag. FloatingPanel clears this on the next mouse-up.
    AppState.shared.appDelegate?.panel.isDragging = true

    let provider = NSItemProvider()

    // Image item: hand over normalized PNG data so other apps accept the drop.
    if item.hasImage,
       let data = item.item.imageData,
       let rep = NSBitmapImageRep(data: data),
       let png = rep.representation(using: .png, properties: [:]) {
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.png.identifier,
        visibility: .all
      ) { completion in
        completion(png, nil)
        return nil
      }
      return provider
    }

    // Text item.
    let text = item.text
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier,
      visibility: .all
    ) { completion in
      completion(Data(text.utf8), nil)
      return nil
    }
    return provider
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
