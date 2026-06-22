import AppKit
import SwiftHEXColors
import SwiftUI
import UniformTypeIdentifiers

struct CardItemView: View {
  let item: HistoryItemDecorator
  let onSelect: () -> Void

  @State private var isHovered = false

  static let cardWidth = FloatingGlassStyle.cardWidth
  static let cardHeight = FloatingGlassStyle.cardHeight
  static let cardRadius = FloatingGlassStyle.cardRadius
  private static let footerHeight: CGFloat = 28

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
    .clipShape(RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous))
    .modifier(FloatingGlassCardBackground(isHovered: isHovered))
    .overlay {
      if item.isSelected {
        RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous)
          .strokeBorder(Color.accentColor.opacity(0.95), lineWidth: 2.5)
          .shadow(color: Color.accentColor.opacity(0.45), radius: 5)
      }
    }
    .overlay(alignment: .topLeading) {
      if let key = item.shortcuts.first?.description.last {
        Text(String(key))
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)
          .frame(width: 20, height: 20)
          .background(Color(red: 0.18, green: 0.35, blue: 0.72).opacity(0.92))
          .clipShape(Circle())
          .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7))
          .padding(7)
      }
    }
    .overlay(alignment: .topTrailing) {
      if item.isPinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 9))
          .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.47))
          .padding(8)
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
    .offset(y: isHovered ? -2 : 0)
    .animation(.easeOut(duration: 0.16), value: isHovered)
    .accessibilityElement(children: .ignore)
    .accessibilityIdentifier("copy-history-item")
    .accessibilityLabel(Text(item.title.isEmpty ? "Image" : item.title))
    .accessibilityValue(Text(item.text))
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { onSelect() }
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
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .frame(height: 26, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.26))
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var textCard: some View {
    Text(item.text)
      .font(.system(size: 11.5))
      .foregroundStyle(.primary)
      .lineLimit(5)
      .multilineTextAlignment(.leading)
      .padding(.horizontal, 11)
      .padding(.top, FloatingGlassStyle.textCardTopPadding)
      .padding(.bottom, Self.footerHeight + 4)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var cardFooter: some View {
    HStack(spacing: 4) {
      AppImageView(appImage: item.applicationImage, size: NSSize(width: 13, height: 13))
      Text(timeString)
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 9)
    .frame(height: Self.footerHeight)
    .background(Color.white.opacity(0.08))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.white.opacity(0.16))
        .frame(height: 0.5)
    }
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

private struct FloatingGlassCardBackground: ViewModifier {
  let isHovered: Bool

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CardItemView.cardRadius, style: .continuous)

    if #available(macOS 26.0, *) {
      content
        .background(Color.white.opacity(isHovered ? 0.18 : 0.11), in: shape)
        .glassEffect(
          .regular
            .tint(FloatingGlassStyle.cardTint.opacity(isHovered ? 0.30 : 0.22))
            .interactive(),
          in: .rect(cornerRadius: CardItemView.cardRadius)
        )
        .modifier(FloatingGlassRim(isHovered: isHovered))
    } else {
      content
        .background(.regularMaterial, in: shape)
        .overlay(shape.fill(FloatingGlassStyle.cardTint.opacity(isHovered ? 0.27 : 0.20)))
        .modifier(FloatingGlassRim(isHovered: isHovered))
    }
  }
}

private struct FloatingGlassRim: ViewModifier {
  let isHovered: Bool

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CardItemView.cardRadius, style: .continuous)
    content
      .overlay {
        shape.strokeBorder(
          LinearGradient(
            colors: [
              .white.opacity(isHovered ? 0.92 : 0.68),
              FloatingGlassStyle.rimTint.opacity(isHovered ? 0.72 : 0.42),
              .white.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: isHovered ? 1.5 : 1
        )
      }
      .shadow(
        color: Color(red: 0.03, green: 0.12, blue: 0.36).opacity(isHovered ? 0.34 : 0.24),
        radius: isHovered ? 12 : 9,
        x: 0,
        y: isHovered ? 8 : 6
      )
  }
}
