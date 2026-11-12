import AppKit
import Defaults
import SwiftHEXColors
import SwiftUI
import UniformTypeIdentifiers

struct CardItemView: View {
  let item: HistoryItemDecorator
  let isHovered: Bool
  let onSelect: () -> Void

  @State private var selectionPopEpoch = 0
  @State private var showingRename = false
  @State private var favoriteName = ""
  @State private var renameFailed = false

  static let cardWidth = FloatingGlassStyle.cardWidth
  static let cardHeight = FloatingGlassStyle.cardHeight
  static let cardRadius = FloatingGlassStyle.cardRadius
  private static let footerHeight: CGFloat = 28

  @MainActor
  static func togglePin(_ item: HistoryItemDecorator, in history: History) {
    history.togglePin(item)
  }

  @MainActor
  static func remove(_ item: HistoryItemDecorator, from history: History) {
    history.delete(item)
  }

  private static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
  }()

  private var timeString: String {
    Self.relativeDateTimeFormatter.localizedString(for: item.item.lastCopiedAt, relativeTo: Date())
  }

  private var detectedColor: NSColor? {
    Self.contentColor(for: item)
  }

  static func contentColor(for item: HistoryItemDecorator) -> NSColor? {
    NSColor(hexString: item.text.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private var shortcutBadgeLabel: String? {
    if let pin = item.item.pin, !pin.isEmpty {
      return "⌘\(pin.uppercased())"
    }
    if let number = item.numericShortcut {
      return "⌘\(number)"
    }
    return nil
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      cardContent
      cardFooter
    }
    .frame(width: Self.cardWidth, height: Self.cardHeight)
    .clipShape(RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous))
    .modifier(FloatingGlassCardBackground(isHovered: isHovered))
    // Scale only the visual layer, applied before the hover/tap/drag modifiers below,
    // so the card's hit-test frame stays fixed at cardWidth/cardHeight even while the
    // pop animation is scaling the rendered content up to 6%. Otherwise the growing
    // hit area bulges into neighboring cards and steals their hover/click. See 3c6242e
    // for the same bug previously fixed at the window level.
    .keyframeAnimator(initialValue: CGFloat(1.0), trigger: selectionPopEpoch) { content, scale in
      content.scaleEffect(scale, anchor: .center)
    } keyframes: { _ in
      LinearKeyframe(1.06, duration: 0.07)
      SpringKeyframe(1.0, duration: 0.22, spring: .bouncy(duration: 0.22, extraBounce: 0.05))
    }
    .contentShape(RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous))
    .overlay {
      if item.isSelected {
        RoundedRectangle(cornerRadius: Self.cardRadius, style: .continuous)
          .strokeBorder(Color.accentColor.opacity(0.95), lineWidth: 2.5)
          .shadow(color: Color.accentColor.opacity(0.45), radius: 5)
          .allowsHitTesting(false)
      }
    }
    .overlay(alignment: .topLeading) {
      if let label = shortcutBadgeLabel {
        Text(label)
          .font(.system(size: 10.5, weight: .semibold))
          .foregroundStyle(.white.opacity(0.9))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.black.opacity(0.4), in: Capsule())
          .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
          .padding(6)
          .allowsHitTesting(false)
      }
    }
    .onTapGesture { onSelect() }
    .contextMenu {
      Button(item.isPinned ? "star_remove" : "star_add") {
        Self.togglePin(item, in: AppState.shared.history)
      }
      if item.isPinned {
        Button("star_rename") {
          favoriteName = item.item.favoriteName ?? ""
          showingRename = true
        }
      }
      Button("clipboard_remove", role: .destructive) {
        Self.remove(item, from: AppState.shared.history)
      }
    }
    .alert("star_rename", isPresented: $showingRename) {
      TextField("star_name_placeholder", text: $favoriteName)
      Button("star_save") {
        renameFailed = !AppState.shared.history.setFavoriteName(item, name: favoriteName)
      }
      Button("clear_alert_cancel", role: .cancel) {}
    } message: {
      Text("star_name_comment")
    }
    .alert("star_name_failed", isPresented: $renameFailed) {
      Button("star_ok", role: .cancel) {}
    }
    .onDrag {
      dragProvider()
    } preview: {
      dragPreview()
    }
    .overlay(alignment: .topTrailing) {
      pinControl
    }
    .onAppear {
      AppState.shared.appDelegate?.panel.finishPrewarming()
      item.ensureThumbnailImage()
    }
    .onDisappear {
      item.releaseThumbnailImage()
      item.releasePreviewImage()
      AppState.shared.appDelegate?.hidePreviewSoon(for: item)
    }
    // No hover lift: shifting the card with .offset moves the visual but not the
    // hit area, so the hover/click would land on the wrong spot. Hover feedback
    // comes from the rim/glow/shadow instead.
    .animation(.easeOut(duration: 0.16), value: isHovered)
    .onChange(of: item.isSelected) { _, isSelected in
      guard isSelected else { return }
      selectionPopEpoch += 1
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("copy-history-item")
    .accessibilityLabel(Text(item.title.isEmpty ? "Image" : item.title))
    .accessibilityValue(Text(item.text))
    .accessibilityAddTraits(.isButton)
    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
    .accessibilityAction { onSelect() }
  }

  // Clipboard favorites reuse legacy Pin storage and shortcuts; Collection Pin is separate.
  // Hovering a normal card reveals a Star pill — both a clickable button and a
  // visible hint for the Option-P shortcut.
  @ViewBuilder
  private var pinControl: some View {
    if item.isPinned {
      Button {
        Task { @MainActor in
          Self.togglePin(item, in: AppState.shared.history)
        }
      } label: {
        Image(systemName: "star.fill")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(Color(red: 1, green: 0.83, blue: 0.47))
          .frame(width: 22, height: 22)
          .background(isHovered ? Color.black.opacity(0.28) : .clear, in: Circle())
      }
      .buttonStyle(.plain)
      .help(Text("star_remove"))
      .padding(6)
    } else if isHovered {
      Button {
        Task { @MainActor in
          Self.togglePin(item, in: AppState.shared.history)
        }
      } label: {
        HStack(spacing: 3) {
          Image(systemName: "star")
            .font(.system(size: 9, weight: .semibold))
          Text("⌥P")
            .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.4), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
      }
      .buttonStyle(.plain)
      .help(Text("star_add"))
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
      .contentShape(Rectangle())
      .overlay(alignment: .bottomLeading) {
        if let name = item.item.favoriteName {
          Text(name).font(.system(size: 11)).lineLimit(1)
            .padding(5).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .padding(6).allowsHitTesting(false)
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private func colorCard(color: NSColor) -> some View {
    VStack(spacing: 0) {
      Color(nsColor: color)
        .frame(height: Self.cardHeight - Self.footerHeight - 26)
      Text(item.title)
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .padding(.horizontal, 6)
        .frame(height: 26, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var textCard: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let name = item.item.favoriteName {
        Text(name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
      }
      Text(item.text)
        .font(.system(size: FloatingGlassStyle.cardBodyFontSize))
        .foregroundStyle(.primary)
        .lineLimit(item.item.favoriteName == nil ? 5 : 3)
    }
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
        .font(.system(size: FloatingGlassStyle.metadataFontSize))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 9)
    .frame(height: Self.footerHeight)
    .background(Color.primary.opacity(0.04))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.primary.opacity(0.10))
        .frame(height: 0.5)
    }
  }

  private func dragProvider() -> NSItemProvider {
    // Keep the panel open while the drag is in flight, otherwise resignKey closes it
    // and cancels the drag. FloatingPanel clears this on the next mouse-up.
    AppState.shared.appDelegate?.panel.isDragging = true

    // File item: hand the real file URL to the OS so Finder / other apps accept a file drop.
    // Only drag as a file if the file actually exists at the stored URL and it's not an image
    // item (Universal Clipboard images have both fileURLs and hasImage = true; prefer PNG drag).
    if let url = item.item.fileURLs.first,
       !item.hasImage,
       (try? url.checkResourceIsReachable()) == true,
       let provider = NSItemProvider(contentsOf: url) {
      return provider
    }

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
    if let url = item.item.fileURLs.first, !item.hasImage {
      HStack(spacing: 8) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
          .resizable()
          .frame(width: 28, height: 28)
        Text(url.lastPathComponent)
          .font(.system(size: 12))
          .lineLimit(2)
      }
      .padding(10)
      .frame(maxWidth: 220, alignment: .leading)
      .background(.regularMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    } else if let image = item.thumbnailImage {
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

struct FloatingGlassCardBackground: ViewModifier {
  let isHovered: Bool
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CardItemView.cardRadius, style: .continuous)

    if reduceTransparency {
      content
        .background(.regularMaterial, in: shape)
        .modifier(NeutralGlassRim(isHovered: isHovered))
    } else {
      // The 2.6.1 frosted card with a cool tint wash.
      content
        .background(.regularMaterial, in: shape)
        .overlay(shape.fill(FloatingGlassStyle.cardTint.opacity(isHovered ? 0.14 : 0.07)).allowsHitTesting(false))
        .modifier(SpectralGlassRim(isHovered: isHovered))
    }
  }
}

private struct NeutralGlassRim: ViewModifier {
  let isHovered: Bool

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CardItemView.cardRadius, style: .continuous)
    content
      .overlay {
        shape.strokeBorder(
          Color.primary.opacity(isHovered ? 0.2 : 0.08),
          lineWidth: 1
        )
      }
      .shadow(
        color: .black.opacity(isHovered ? 0.16 : 0.08),
        radius: isHovered ? 10 : 6,
        x: 0,
        y: 4
      )
  }
}

/// The original (2.6.1) card rim: gloss-to-cyan-to-pink gradient, soft drop shadow and a
/// cool glow that blooms on the hovered card only.
private struct SpectralGlassRim: ViewModifier {
  let isHovered: Bool

  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CardItemView.cardRadius, style: .continuous)
    let isDark = colorScheme == .dark
    let leadOpacity: Double = isDark ? (isHovered ? 0.92 : 0.68) : (isHovered ? 0.28 : 0.18)
    let trailOpacity: Double = isDark ? 0.18 : 0.10
    content
      .overlay {
        shape.strokeBorder(
          LinearGradient(
            colors: [
              Color.primary.opacity(leadOpacity),
              FloatingGlassStyle.rimTint.opacity(isHovered ? 0.72 : 0.42),
              FloatingGlassStyle.spectralTint.opacity(isHovered ? 0.32 : 0.18),
              Color.primary.opacity(trailOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: isHovered ? 1.5 : 1
        )
        .allowsHitTesting(false)
      }
      .shadow(
        color: Color(red: 0.05, green: 0.07, blue: 0.10).opacity(isHovered ? 0.26 : 0.18),
        radius: isHovered ? 12 : 9,
        x: 0,
        y: isHovered ? 8 : 6
      )
      .shadow(
        color: FloatingGlassStyle.rimTint.opacity(isHovered ? 0.5 : 0),
        radius: isHovered ? 10 : 0
      )
  }
}
