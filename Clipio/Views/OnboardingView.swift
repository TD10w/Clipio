import Defaults
import KeyboardShortcuts
import LaunchAtLogin
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
  case shortcut, practice, autoPaste, collection, finish
}

/// Interactive Getting Started guide: pick the shortcut, practise copy → open → paste,
/// optionally let Clipio paste for you, peek at Collection, then confirm login launch.
/// The practice steps watch the real shelf, so a tick means the user really did it.
struct OnboardingView: View {
  let onFinish: (_ launchAtLogin: Bool) -> Void

  @State private var appState = AppState.shared
  @State private var step = OnboardingStep.shortcut
  @Default(.menuIcon) private var menuIcon
  @Default(.showInStatusBar) private var showInStatusBar
  @Default(.pasteByDefault) private var pasteByDefault

  @State private var shortcut = KeyboardShortcuts.Name.popup.shortcut
  @State private var recording = false
  @State private var shortcutBeforeRecording: KeyboardShortcuts.Shortcut?
  @State private var shortcutWarning: String?

  @State private var copiedSample = false
  @State private var openedShelf = false
  @State private var practiceText = ""

  @State private var accessibilityTrusted = Accessibility.isTrusted
  @State private var requestedPermission = false
  @State private var autoPasteText = ""

  @State private var openedForCollection = false
  @State private var switchedToCollection = false

  @State private var launchAtLogin: Bool

  private let permissionPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  private static let recommended = KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])

  init(onFinish: @escaping (_ launchAtLogin: Bool) -> Void) {
    self.onFinish = onFinish
    // First run recommends launching at login; a replay shows the current state.
    _launchAtLogin = State(initialValue: Defaults[.hasSeenOnboarding] ? LaunchAtLogin.isEnabled : true)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        Text(verbatim: "Clipio")
          .font(.system(size: FloatingGlassStyle.wordmarkFontSize, weight: .semibold))
      }
      .frame(height: 20)

      Text(verbatim: String(format: "%02d / %02d", step.rawValue + 1, OnboardingStep.allCases.count))
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)
        .accessibilityLabel(String(
          format: NSLocalizedString("onboarding_step", comment: ""),
          step.rawValue + 1, OnboardingStep.allCases.count
        ))
        .padding(.top, 14)

      Group {
        Text(verbatim: title)
          .font(.system(size: 26, weight: .semibold))
          .accessibilityAddTraits(.isHeader)
          .padding(.top, 6)
        Text(verbatim: subtitle)
          .font(.system(size: 13.5))
          .foregroundStyle(.secondary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 8)
        content
          .padding(.top, 20)
      }
      .id(step)
      .transition(.opacity)

      Spacer(minLength: 12)
      footer
    }
    .padding(.horizontal, 32)
    .padding(.top, 12)
    .padding(.bottom, 26)
    // Fill the fixed-size window; a fixed SwiftUI size would make the hosting view
    // grow the window by the title bar's safe-area inset.
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(OnboardingGlassBackground())
    .ignoresSafeArea()
    .animation(.easeInOut(duration: 0.2), value: step)
    .onChange(of: step) { _, newStep in
      shortcut = KeyboardShortcuts.Name.popup.shortcut
      recording = false
      if newStep == .practice || newStep == .autoPaste {
        appState.switchShelf(to: .clipboard)
      }
    }
    .onChange(of: appState.shelfExpanded) { _, expanded in
      guard expanded else { return }
      switch step {
      case .practice: openedShelf = true
      case .collection:
        if appState.shelfMode == .collection { openedForCollection = true }
      default: break
      }
    }
    .onChange(of: appState.shelfMode) { _, mode in
      guard step == .collection, !appState.popup.isClosed() else { return }
      // Tab from Clipboard into Collection also counts as finding Collection;
      // any switch after that completes the Tab task.
      if openedForCollection { switchedToCollection = true }
      if mode == .collection { openedForCollection = true }
    }
    .onReceive(permissionPoll) { _ in
      guard step == .autoPaste, requestedPermission, !accessibilityTrusted, Accessibility.isTrusted else { return }
      accessibilityTrusted = true
      pasteByDefault = true
      OnboardingController.bringGuideToFront()
    }
  }

  // MARK: - Copy

  private var shortcutText: String? { shortcut?.description }
  private var isRecommended: Bool { shortcut == Self.recommended }
  private var autoPasteOn: Bool { accessibilityTrusted && pasteByDefault }

  private func L(_ key: String) -> String { NSLocalizedString(key, comment: "") }
  private func L(_ key: String, _ argument: String) -> String { String(format: L(key), argument) }

  private var title: String {
    switch step {
    case .shortcut: L("onboarding_shortcut_title")
    case .practice: L("onboarding_practice_title")
    case .autoPaste: L("onboarding_autopaste_title")
    case .collection: L("onboarding_collection_title")
    case .finish: L("onboarding_finish_title")
    }
  }

  private var subtitle: String {
    switch step {
    case .shortcut: L("onboarding_shortcut_body")
    case .practice: L("onboarding_practice_body")
    case .autoPaste: L("onboarding_autopaste_body")
    case .collection: L("onboarding_collection_body")
    case .finish: L("onboarding_finish_body")
    }
  }

  private var openTaskTitle: String {
    if let shortcutText { L("onboarding_task_open", shortcutText) } else { L("onboarding_task_open_unset") }
  }

  // MARK: - Steps

  @ViewBuilder
  private var content: some View {
    switch step {
    case .shortcut: shortcutStep
    case .practice: practiceStep
    case .autoPaste: autoPasteStep
    case .collection: collectionStep
    case .finish: finishStep
    }
  }

  private var shortcutStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          if recording {
            OnboardingShortcutRecorder(onChange: shortcutChanged)
              .frame(width: 190)
            Button("onboarding_cancel") {
              recording = false
              shortcut = KeyboardShortcuts.Name.popup.shortcut
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Spacer()
          } else {
            OnboardingKeyCap(text: shortcutText ?? L("onboarding_shortcut_none"), large: true)
            if isRecommended { OnboardingBadge(key: "onboarding_recommended") }
            Spacer()
            Button("onboarding_change") {
              shortcutWarning = nil
              shortcutBeforeRecording = shortcut
              recording = true
            }
            .controlSize(.large)
            .accessibilityIdentifier("onboarding-change-shortcut")
          }
        }
        .frame(minHeight: 40)

        Group {
          if let shortcutWarning {
            Text(verbatim: shortcutWarning).foregroundStyle(.orange)
          } else if recording {
            Text("onboarding_shortcut_recording").foregroundStyle(.secondary)
          } else if !isRecommended {
            Button(L("onboarding_use_recommended", Self.recommended.description)) {
              KeyboardShortcuts.setShortcut(Self.recommended, for: .popup)
              shortcut = Self.recommended
            }
            .buttonStyle(.link)
          } else {
            Text("onboarding_shortcut_why").foregroundStyle(.secondary)
          }
        }
        .font(.system(size: 12))
      }
      .onboardingCard()

      Text("onboarding_shortcut_later")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }

  private var practiceStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        OnboardingTaskRow(
          done: copiedSample, current: !copiedSample,
          title: L("onboarding_task_copy"), detail: L("onboarding_task_copy_detail")
        ) {
          Button("onboarding_copy_sample", action: copySample)
            .controlSize(.small)
            .accessibilityIdentifier("onboarding-copy-sample")
        }
        Divider().opacity(0.5)
        OnboardingTaskRow(
          done: openedShelf, current: copiedSample && !openedShelf,
          title: openTaskTitle, detail: L("onboarding_task_open_detail")
        )
        Divider().opacity(0.5)
        OnboardingTaskRow(
          done: !practiceText.isEmpty, current: openedShelf && practiceText.isEmpty,
          title: L(pasteByDefault ? "onboarding_task_paste_auto" : "onboarding_task_paste"),
          detail: L(pasteByDefault ? "onboarding_task_paste_auto_detail" : "onboarding_task_paste_detail")
        )
      }
      .onboardingCard()

      OnboardingPasteField(text: $practiceText, identifier: "onboarding-paste-field")
    }
  }

  @ViewBuilder
  private var autoPasteStep: some View {
    if autoPasteOn {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 0) {
          OnboardingTaskRow(
            done: true, current: false,
            title: L("onboarding_autopaste_on"), detail: L("onboarding_autopaste_on_detail")
          )
          Divider().opacity(0.5)
          OnboardingTaskRow(
            done: !autoPasteText.isEmpty, current: true,
            title: shortcutText.map { L("onboarding_autopaste_try", $0) } ?? L("onboarding_task_open_unset"),
            detail: L("onboarding_autopaste_try_detail")
          )
        }
        .onboardingCard()

        OnboardingPasteField(text: $autoPasteText, identifier: "onboarding-autopaste-field")
      }
    } else {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
              .font(.system(size: 20))
              .foregroundStyle(Color.accentColor)
              .frame(width: 24)
            Text("onboarding_autopaste_privacy")
              .font(.system(size: 12.5))
              .foregroundStyle(.secondary)
              .lineSpacing(3)
              .fixedSize(horizontal: false, vertical: true)
          }
          HStack(spacing: 16) {
            Button(accessibilityTrusted ? "onboarding_autopaste_turn_on" : "onboarding_autopaste_allow") {
              requestAutoPaste()
            }
            .controlSize(.large)
            .accessibilityIdentifier("onboarding-allow-paste")
            Button("onboarding_not_now") { step = .collection }
              .buttonStyle(.plain)
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("onboarding-not-now")
          }
          if requestedPermission && !accessibilityTrusted {
            HStack(spacing: 8) {
              ProgressView().controlSize(.small)
              Text("onboarding_autopaste_waiting")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
              Button("onboarding_open_settings", action: Self.openAccessibilitySettings)
                .buttonStyle(.link)
            }
            .font(.system(size: 12))
          }
        }
        .onboardingCard()

        Text("onboarding_autopaste_later")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
    }
  }

  private var collectionStep: some View {
    let collectionShortcut = KeyboardShortcuts.Name.collectionPopup.shortcut?.description
    return VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        OnboardingTaskRow(
          done: openedForCollection, current: !openedForCollection,
          title: collectionShortcut.map { L("onboarding_task_open_collection", $0) }
            ?? L("onboarding_task_open_collection_unset"),
          detail: L("onboarding_task_open_collection_detail")
        )
        Divider().opacity(0.5)
        OnboardingTaskRow(
          done: switchedToCollection, current: openedForCollection && !switchedToCollection,
          title: L("onboarding_task_tab")
        )
      }
      .onboardingCard()

      Text("onboarding_optional")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }

  private var finishStep: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 14) {
        menuBarIcon
          .frame(width: 36, height: 36)
          .background(.regularMaterial, in: Circle())
          .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5))
        VStack(alignment: .leading, spacing: 2) {
          Text("onboarding_finish_menu_bar").font(.system(size: 13.5, weight: .medium))
          Text("onboarding_finish_menu_bar_detail").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        if let shortcutText { OnboardingKeyCap(text: shortcutText) }
      }
      .onboardingCard()

      Toggle(isOn: $launchAtLogin) {
        Text("onboarding_launch_at_login").font(.system(size: 13.5))
      }
      .toggleStyle(.checkbox)
      .accessibilityIdentifier("onboarding-launch-at-login")
      .onboardingCard()

      if !showInStatusBar {
        Button("onboarding_show_icon") { showInStatusBar = true }
          .accessibilityIdentifier("onboarding-show-icon")
      }

      Text("onboarding_hidden_icon")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var menuBarIcon: some View {
    if menuIcon == .scissors {
      Text(verbatim: "✂︎").font(.system(size: 17))
    } else {
      Image(nsImage: menuIcon.image)
        .resizable()
        .scaledToFit()
        .frame(width: 18, height: 18)
    }
  }

  // MARK: - Footer

  private var canAdvance: Bool {
    step != .practice || !practiceText.isEmpty
  }

  private var footer: some View {
    HStack(spacing: 18) {
      Button("onboarding_skip") { step = .finish }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .keyboardShortcut(.cancelAction)
        .opacity(step == .finish ? 0 : 1)
        .disabled(step == .finish)
        .accessibilityIdentifier("onboarding-skip")
      Button("onboarding_back") {
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) { step = previous }
      }
      .buttonStyle(.plain)
      .disabled(step == .shortcut)
      .accessibilityIdentifier("onboarding-back")
      Spacer()
      HStack(spacing: 6) {
        ForEach(OnboardingStep.allCases, id: \.self) { item in
          Capsule()
            .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.25))
            .frame(width: item == step ? 18 : 6, height: 6)
        }
      }
      .accessibilityHidden(true)
      Spacer()
      Button(step == .finish ? "onboarding_finish" : "onboarding_next") {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
          step = next
        } else {
          onFinish(launchAtLogin)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .keyboardShortcut(.defaultAction)
      .disabled(!canAdvance)
      .accessibilityIdentifier("onboarding-next")
    }
    .font(.system(size: 13))
  }

  // MARK: - Actions

  private func shortcutChanged(_ newShortcut: KeyboardShortcuts.Shortcut?) {
    recording = false
    if let newShortcut, Self.isReserved(newShortcut) {
      KeyboardShortcuts.setShortcut(shortcutBeforeRecording, for: .popup)
      shortcutWarning = L("onboarding_shortcut_reserved", newShortcut.description)
    } else if newShortcut == nil {
      // Clearing the only way in makes no sense mid-guide; keep the previous one.
      KeyboardShortcuts.setShortcut(shortcutBeforeRecording, for: .popup)
    } else {
      shortcutWarning = nil
    }
    shortcut = KeyboardShortcuts.Name.popup.shortcut
  }

  /// Plain ⌘ + an everyday editing key would hijack copy/paste/undo in every app.
  static func isReserved(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
    let everyday: [KeyboardShortcuts.Key] = [.a, .c, .q, .s, .v, .w, .x, .z]
    guard shortcut.modifiers == [.command], let key = shortcut.key else { return false }
    return everyday.contains(key)
  }

  private func copySample() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(L("onboarding_sample_text"), forType: .string)
    // Record it now rather than at the next poll, so it's first on the shelf.
    Clipboard.shared.checkForChangesInPasteboard()
    copiedSample = true
  }

  private func requestAutoPaste() {
    if Accessibility.isTrusted {
      accessibilityTrusted = true
      pasteByDefault = true
    } else {
      // Adds Clipio (switched off) to the Accessibility list; macOS shows no dialog,
      // so take the user straight to the list.
      _ = Accessibility.requestTrust()
      requestedPermission = true
      Self.openAccessibilitySettings()
    }
  }

  private static func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
      NSWorkspace.shared.open(url)
    }
  }
}
