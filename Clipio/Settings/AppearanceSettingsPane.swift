import AppKit
import SwiftUI
import Defaults
import Settings

struct AppearanceSettingsPane: View {
  @Default(.shelfGlassOpacity) private var shelfGlassOpacity
  @Default(.appearanceMode) private var appearanceMode
  @Default(.popupPosition) private var popupAt
  @Default(.popupScreen) private var popupScreen
  @Default(.pinTo) private var pinTo
  @Default(.imageMaxHeight) private var imageHeight
  @Default(.previewDelay) private var previewDelay
  @Default(.highlightMatch) private var highlightMatch
  @Default(.menuIcon) private var menuIcon
  @Default(.showInStatusBar) private var showInStatusBar
  @Default(.showSearch) private var showSearch
  @Default(.searchVisibility) private var searchVisibility
  @Default(.showFooter) private var showFooter
  @Default(.windowPosition) private var windowPosition
  @Default(.showApplicationIcons) private var showApplicationIcons

  @State private var screens = NSScreen.screens

  private let imageHeightFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 200
    return formatter
  }()

  private let numberOfItemsFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 0
    formatter.maximum = 100
    return formatter
  }()

  private let titleLengthFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 30
    formatter.maximum = 200
    return formatter
  }()

  private let previewDelayFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 200
    formatter.maximum = 100_000
    return formatter
  }()

  var body: some View {
    Settings.Container(contentWidth: 650) {
      Settings.Section(label: { Text("Appearance") }) {
        Picker("", selection: $appearanceMode) {
          ForEach(AppearanceMode.allCases) { mode in
            Text(mode.description).tag(mode)
          }
        }
        .labelsHidden()
        .frame(width: 141, alignment: .leading)
        .help(Text("Light, Dark, or follow the system."))
      }

      Settings.Section(label: { Text("glass_appearance") }) {
        HStack(spacing: 8) {
          Text("glass_more_clear").font(.caption).foregroundStyle(.secondary)
          Slider(value: $shelfGlassOpacity, in: 0...1)
            .frame(width: 160)
            .accessibilityLabel(Text("glass_appearance"))
            .accessibilityIdentifier("glass-opacity-slider")
          Text("glass_more_opaque").font(.caption).foregroundStyle(.secondary)
        }
        .help(Text("glass_appearance_help"))
      }

      Settings.Section(title: "") {
        GlassTransparencyPreview()
      }

      Settings.Section(label: { Text("PopupAt", tableName: "AppearanceSettings") }) {
        HStack {
          Picker("", selection: $popupAt) {
            ForEach(PopupPosition.allCases) { position in
              if position == .center || position == .lastPosition, screens.count > 1 {
                screenPicker(for: position)
              } else {
                Text(position.description)
              }
            }
          }
          .labelsHidden()
          .frame(width: 141, alignment: .leading)
          .help(Text("PopupAtTooltip", tableName: "AppearanceSettings"))

          if popupAt == .lastPosition {
            Button {
              _windowPosition.reset()
            } label: {
              Image(systemName: "arrow.uturn.backward.circle.fill")
                .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .help(Text("PopupAtLastLocationReset", tableName: "AppearanceSettings"))
            .disabled(windowPosition == _windowPosition.defaultValue)
          }
        }
      }

      Settings.Section(label: { Text("PinTo", tableName: "AppearanceSettings") }) {
        Picker("", selection: $pinTo) {
          ForEach(PinsPosition.allCases) { position in
            Text(position.description)
          }
        }
        .labelsHidden()
        .frame(width: 141, alignment: .leading)
        .help(Text("PinToTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(label: { Text("ImageHeight", tableName: "AppearanceSettings") }) {
        HStack {
          TextField("", value: $imageHeight, formatter: imageHeightFormatter)
            .frame(width: 120)
            .help(Text("ImageHeightTooltip", tableName: "AppearanceSettings"))
          Stepper("", value: $imageHeight, in: 1...200)
            .labelsHidden()
        }
      }

      Settings.Section(label: { Text("PreviewDelay", tableName: "AppearanceSettings") }) {
        HStack {
          TextField("", value: $previewDelay, formatter: previewDelayFormatter)
            .frame(width: 120)
            .help(Text("PreviewDelayTooltip", tableName: "AppearanceSettings"))
          Stepper("", value: $previewDelay, in: 200...100_000)
            .labelsHidden()
        }
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("HighlightMatches", tableName: "AppearanceSettings") }
      ) {
        Picker("", selection: $highlightMatch) {
          ForEach(HighlightMatch.allCases) { match in
            Text(match.description)
          }
        }
        .labelsHidden()
        .frame(width: 141, alignment: .leading)
        .help(Text("HighlightMatchesTooltip", tableName: "AppearanceSettings"))
      }

      Settings.Section(title: "") {
        Defaults.Toggle(key: .showSpecialSymbols) {
          Text("ShowSpecialSymbols", tableName: "AppearanceSettings")
        }
        .help(Text("ShowSpecialSymbolsTooltip", tableName: "AppearanceSettings"))

        HStack {
          Defaults.Toggle(key: .showInStatusBar) {
            Text("ShowMenuIcon", tableName: "AppearanceSettings")
          }

          Picker("", selection: $menuIcon) {
            ForEach(MenuIcon.allCases) { icon in
              Image(nsImage: icon.image)
            }
          }
          .labelsHidden()
          .scaledToFit()
          .disabled(!showInStatusBar)
          .controlSize(.small)
        }

        Defaults.Toggle(key: .showRecentCopyInMenuBar) {
          Text("ShowRecentCopyInMenuBar", tableName: "AppearanceSettings")
        }
        HStack {
          Defaults.Toggle(key: .showSearch) {
            Text("ShowSearchField", tableName: "AppearanceSettings")
          }

          Picker("", selection: $searchVisibility) {
            ForEach(SearchVisibility.allCases) { type in
              Text(type.description)
            }
          }
          .labelsHidden()
          .scaledToFit()
          .disabled(!showSearch)
          .controlSize(.small)
        }
        Defaults.Toggle(key: .showTitle) {
          Text("ShowTitleBeforeSearchField", tableName: "AppearanceSettings")
        }
        Defaults.Toggle(key: .showApplicationIcons) {
          Text("ShowApplicationIcons", tableName: "AppearanceSettings")
        }

        Defaults.Toggle(key: .showFooter) {
          Text("ShowFooter", tableName: "AppearanceSettings")
        }
        Text("OpenPreferencesWarning", tableName: "AppearanceSettings")
          .opacity(showFooter ? 0 : 1)
          .controlSize(.small)
          .foregroundStyle(.gray)
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
      screens = NSScreen.screens
    }
  }

  @ViewBuilder
  private func screenPicker(for position: PopupPosition) -> some View {
    let screenBinding: Binding<Int> = Binding {
      return popupScreen
    } set: {
      popupScreen = $0
      popupAt = position
    }

    Picker(selection: screenBinding) {
      Text(labelForScreen(index: 0))
        .tag(0)

      ForEach(screens.indices, id: \.self) { index in
        Text(labelForScreen(index: index + 1))
          .tag(index + 1)
      }
    } label: {
      if popupAt == position {
        Text("\(position.description) (\(labelForScreen(index: popupScreen)))")
      } else {
        Text(position.description)
      }
    }
  }

  private func labelForScreen(index screenIndex: Int) -> String {
    switch screenIndex {
    case 0:
      return String(localized: "ActiveScreen", table: "AppearanceSettings")
    case _:
      return screens[screenIndex - 1].localizedName
    }
  }
}

#Preview {
  AppearanceSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}

/// Live preview for the transparency slider: a miniature shelf over an ordinary page of
/// text. Real glass refraction garbles a tiny in-window sample, so the preview blurs a
/// copy of the page directly (same 0→1 strength as the shelf's blur) and applies the
/// shelf's own tint, card and rim styling.
private struct GlassTransparencyPreview: View {
  @Default(.shelfGlassOpacity) private var opacity
  @Environment(\.colorScheme) private var colorScheme

  private static let shelfSize = CGSize(width: 300, height: 84)
  private static let maxBlurRadius: CGFloat = 14
  private static let lines = [
    "Meeting notes · 会议记录 · Tuesday 10:30",
    "Ship the collection shelf, then tidy the README",
    "把这一段文字放在 Clipio 面板后面，看会不会叠字",
    "The quick brown fox jumps over the lazy dog",
    "Q4 plan · budget · design review · 设计评审",
    "Drag files to the top of the screen to collect them"
  ]

  var body: some View {
    let frame = RoundedRectangle(cornerRadius: 12, style: .continuous)
    let shelf = RoundedRectangle(cornerRadius: 20, style: .continuous)
    let dark = colorScheme == .dark
    ZStack {
      samplePage
      samplePage
        .blur(radius: Self.maxBlurRadius * FloatingGlassStyle.blurOpacity(opacity), opaque: true)
        .mask { shelf.frame(width: Self.shelfSize.width, height: Self.shelfSize.height) }
      shelf
        .fill((dark ? Color.black : Color.white).opacity(FloatingGlassStyle.tintOpacity(opacity, dark: dark)))
        .frame(width: Self.shelfSize.width, height: Self.shelfSize.height)
      miniShelf
        .overlay(ShelfGlassRim(radius: 20))
    }
    .frame(width: 360, height: 128)
    .clipShape(frame)
    .overlay(frame.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    .accessibilityHidden(true)
  }

  private var samplePage: some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(Self.lines, id: \.self) { line in
        Text(verbatim: line)
          .font(.system(size: 12))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .background(Color(nsColor: .textBackgroundColor))
  }

  private var miniShelf: some View {
    HStack(spacing: 8) {
      Text(verbatim: "Clipio")
        .font(.system(size: 13, weight: .semibold))
        .padding(.trailing, 2)
      miniCard { Text(verbatim: "Hello, Clipio").font(.system(size: 10)).lineLimit(3) }
      miniCard {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(Color(red: 0.45, green: 0.88, blue: 0.80))
      }
      miniCard { Text(verbatim: "https://apple.com").font(.system(size: 10)).lineLimit(3) }
    }
    .padding(10)
    .frame(width: Self.shelfSize.width, height: Self.shelfSize.height)
  }

  private func miniCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    return content()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(7)
      .frame(width: 62, height: 60)
      .background(.regularMaterial, in: shape)
      .overlay(shape.fill(FloatingGlassStyle.cardTint.opacity(0.07)).allowsHitTesting(false))
      .overlay(shape.strokeBorder(
        LinearGradient(
          colors: [Color.primary.opacity(0.3), FloatingGlassStyle.rimTint.opacity(0.42),
                   FloatingGlassStyle.spectralTint.opacity(0.18)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        lineWidth: 1
      ))
  }
}
