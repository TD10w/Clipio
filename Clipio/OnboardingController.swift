import Defaults
import SwiftUI

/// Owns the guide window; illustrations never read the user's clipboard or files.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private let onStart: () -> Void

  var isVisible: Bool { window?.isVisible == true }

  init(onStart: @escaping () -> Void) {
    self.onStart = onStart
  }

  func showIfNeeded() {
    // Existing UI regressions must keep their usual launch behavior.
    guard !RuntimeEnvironment.isTesting || (
      RuntimeEnvironment.isUITesting && CommandLine.arguments.contains("show-ui-testing-onboarding")
    ), !Defaults[.hasSeenOnboarding] else { return }
    show()
  }

  func show() {
    let window = window ?? makeWindow()
    window.contentView = NSHostingView(rootView: OnboardingView(
      onDismiss: { [weak self] in self?.dismiss() },
      onStart: { [weak self] in self?.start() }
    ))
    window.appearance = Defaults[.appearanceMode].nsAppearance
    if !window.isVisible { window.center() }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillClose(_ notification: Notification) {
    Defaults[.hasSeenOnboarding] = true
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 540),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("onboarding_menu", comment: "")
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.identifier = NSUserInterfaceItemIdentifier("clipio-onboarding")
    window.isReleasedWhenClosed = false
    window.delegate = self
    self.window = window
    return window
  }

  private func dismiss() {
    Defaults[.hasSeenOnboarding] = true
    window?.close()
  }

  private func start() {
    dismiss()
    onStart()
  }
}
