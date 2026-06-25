import AppKit
import SwiftHEXColors
import SwiftUI
import UniformTypeIdentifiers

struct CardItemView: View {
  let item: HistoryItemDecorator
  let onSelect: () -> Void

  @State private var isHovered = false
  @State private var selectionPopEpoch = 0

  static let cardWidth = FloatingGlassStyle.cardWidth
  static let cardHeight = FloatingGlassStyle.cardHeight
  static let cardRadius = FloatingGlassStyle.cardRadius
  private static let footerHeight: CGFloat = 28

  private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()

  private var timeString: String {
    Self.relativeDateTimeFormatter.localizedString(for: item.item.lastCopiedAt, relativeTo: Date())
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
      if let number = item.numericShortcut {
        // Quiet monochrome chip: a constant hint for the ⌘N quick-paste shortcut that
        // doesn't compete with the card content the way the old bright-blue pill did.
        Text("⌘\(number)")
          .font(.system(size: 10.5, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.9))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.black.opacity(0.4), in: Capsule())
          .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
          .padding(6)
      }
    }
    .overlay(alignment: .topTrailing) {
      pinControl
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
      AppState.shared.appDelegate?.panel.finishPrewarming()
      item.ensureThumbnailImage()
    }
    // No hover lift: shifting the card with .offset moves the visual but not the
    // hit area, so the hover/click would land on the wrong spot. Hover feedback
    // comes from the rim/glow/shadow instead.
    .animation(.easeOut(duration: 0.16), value: isHovered)
    .keyframeAnimator(initialValue: CGFloat(1.0), trigger: selectionPopEpoch) { content, scale in
      content.scaleEffect(scale, anchor: .center)
    } keyframes: { _ in
      LinearKeyframe(1.06, duration: 0.07)
      SpringKeyframe(1.0, duration: 0.22, spring: .bouncy(duration: 0.22, extraBounce: 0.05))
    }
    .onChange(of: item.isSelected) { _, isSelected in
      guard isSelected else { return }
      selectionPopEpoch += 1
    }
    .accessibilityElement(children: .ignore)
    .accessibilityIdentifier("copy-history-item")
    .accessibilityLabel(Text(item.title.isEmpty ? "Image" : item.title))
    .accessibilityValue(Text(item.text))
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { onSelect() }
  }

  // Pin affordance in the top-right. Pinned cards show the gold pin (click to unpin).
  // Hovering an unpinned card reveals a "pin ⌥P" pill — both a clickable button and a
  // visible hint for the Option-P shortcut.
  @ViewBuilder
  private var pinControl: some View {
    if item.isPinned {
      Button {
        Task { @MainActor in item.togglePin() }
      } label: {
        Image(systemName: "pin.fill")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.47))
          .frame(width: 22, height: 22)
          .background(isHovered ? Color.black.opacity(0.28) : .clear, in: Circle())
      }
      .buttonStyle(.plain)
      .help("Unpin (⌥P)")
      .padding(6)
    } else if isHovered {
      Button {
        Task { @MainActor in item.togglePin() }
      } label: {
        HStack(spacing: 3) {
          Image(systemName: "pin")
            .font(.system(size: 9, weight: .semibold))
          Text("⌥P")
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.4), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
      }
      .buttonStyle(.plain)
      .help("Pin (⌥P)")
      .padding(6)
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
    .background(Color.white.opacity(0.045))
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

    // Solid frosted material (not glass): adapts to light/dark, renders fast, and
    // gives text + badges an opaque surface to stay crisp against.
    content
      .background(.regularMaterial, in: shape)
      .overlay(shape.fill(FloatingGlassStyle.cardTint.opacity(isHovered ? 0.14 : 0.07)))
      .modifier(FloatingGlassRim(isHovered: isHovered))
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
              FloatingGlassStyle.spectralTint.opacity(isHovered ? 0.32 : 0.18),
              .white.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: isHovered ? 1.5 : 1
        )
      }
      // Soft neutral drop shadow lifts the card off the tray...
      .shadow(
        color: Color(red: 0.05, green: 0.07, blue: 0.10).opacity(isHovered ? 0.26 : 0.18),
        radius: isHovered ? 12 : 9,
        x: 0,
        y: isHovered ? 8 : 6
      )
      // ...plus a cool luminous glow that blooms on hover, like the reference edges.
      // Resting glow is off (radius/opacity 0): a second blurred shadow on every
      // card was recomposited each scroll frame for little visible gain. The glow
      // still blooms on the single hovered card, which costs nothing while scrolling.
      .shadow(
        color: FloatingGlassStyle.rimTint.opacity(isHovered ? 0.5 : 0),
        radius: isHovered ? 10 : 0
      )
  }
}
