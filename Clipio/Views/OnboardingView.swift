import Defaults
import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
  let onDismiss: () -> Void
  let onStart: () -> Void

  @State private var page = 0
  @Default(.menuIcon) private var menuIcon
  @Default(.showInStatusBar) private var showInStatusBar

  private let titles = ["onboarding_entry_title", "onboarding_clipboard_title", "onboarding_collection_title"]
  private let descriptions = ["onboarding_entry_body", "onboarding_clipboard_body", "onboarding_collection_body"]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        Text(verbatim: "Clipio")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.bottom, 22)

      OnboardingIllustration(page: page, menuIcon: menuIcon)
        .frame(height: 210)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 12) {
        Text(String(format: "%02d / 03", page + 1))
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(.secondary)
          .accessibilityLabel(String(format: NSLocalizedString("onboarding_step", comment: ""), page + 1))
        Text(LocalizedStringKey(titles[page]))
          .font(.system(size: 28, weight: .semibold))
          .accessibilityAddTraits(.isHeader)
        Text(LocalizedStringKey(descriptions[page]))
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .lineSpacing(5)
          .fixedSize(horizontal: false, vertical: true)
        if page > 0 {
          shortcut
        } else if !showInStatusBar {
          Button("onboarding_show_icon") { showInStatusBar = true }
            .accessibilityIdentifier("onboarding-show-icon")
        }
      }
      .padding(.top, 24)

      Spacer(minLength: 12)
      HStack(spacing: 18) {
        Button("onboarding_skip", action: onDismiss)
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("onboarding-skip")
        Button("onboarding_back") { page -= 1 }
          .buttonStyle(.plain)
          .disabled(page == 0)
          .accessibilityIdentifier("onboarding-back")
        Spacer()
        HStack(spacing: 6) {
          ForEach(0..<3) { index in
            Capsule()
              .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.25))
              .frame(width: index == page ? 18 : 6, height: 6)
          }
        }
        .accessibilityHidden(true)
        Spacer()
        Button(page == 2 ? "onboarding_start" : "onboarding_next") {
          if page == 2 { onStart() } else { page += 1 }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("onboarding-next")
      }
      .font(.system(size: 13))
    }
    .padding(28)
    .frame(width: 560, height: 540)
    .background(.regularMaterial)
  }

  @ViewBuilder
  private var shortcut: some View {
    let name: KeyboardShortcuts.Name = page == 1 ? .popup : .collectionPopup
    HStack(spacing: 10) {
      if let shortcut = name.shortcut {
        Text(verbatim: shortcut.description)
          .font(.system(size: 16, weight: .medium))
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
          .accessibilityIdentifier("onboarding-shortcut")
        Text(page == 1 ? "onboarding_open_clipboard" : "onboarding_open_collection")
          .foregroundStyle(.secondary)
      } else {
        Text("onboarding_shortcut_unset")
          .foregroundStyle(.secondary)
      }
    }
    .font(.system(size: 12))
    .padding(.top, 2)
  }
}
