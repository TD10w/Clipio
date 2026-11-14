import Defaults
import LaunchAtLogin
import SwiftUI

/// Owns the guide window. The practice steps copy a sample string the user asks for;
/// the guide never reads the user's existing clipboard or files.
@MainActor
final class OnboardingController: NSObject, NSWindowDelegate {
  static let windowIdentifier = NSUserInterfaceItemIdentifier("clipio-onboarding")

  private var window: NSWindow?

  var isVisible: Bool { window?.isVisible == true }

  func showIfNeeded() {
    // Existing UI regressions must keep their usual launch behavior.
    guard !RuntimeEnvironment.isTesting || (
      RuntimeEnvironment.isUITesting && CommandLine.arguments.contains("show-ui-testing-onboarding")
    ), !Defaults[.hasSeenOnboarding] else { return }
    show()
  }

  func show() {
    let window = window ?? makeWindow()
    // A fresh view each time, so replaying the guide starts from step one.
    let host = NSHostingView(rootView: OnboardingView(
      onFinish: { [weak self] launchAtLogin in self?.finish(launchAtLogin: launchAtLogin) }
    ))
    // The window frame is fixed; don't let SwiftUI grow it around the title bar inset.
    host.sizingOptions = []
    window.contentView = host
    window.appearance = Defaults[.appearanceMode].nsAppearance
    window.setFrame(NSRect(origin: window.frame.origin, size: OnboardingMetrics.windowSize), display: false)
    if !window.isVisible { window.center() }
    window.makeKeyAndOrderFront(nil)
    window.invalidateShadow()
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillClose(_ notification: Notification) {
    Defaults[.hasSeenOnboarding] = true
  }

  /// The practice steps open the shelf on top of the guide. When the shelf closes,
  /// hand keyboard focus straight back so the ⌘V (typed, or posted by automatic paste)
  /// lands in the practice box instead of the closing shelf. Only while Clipio is the
  /// active app — otherwise the user is pasting somewhere else and focus must stay there.
  static func reclaimFocusAfterShelf() {
    guard NSApp.isActive,
          let guide = NSApp.windows.first(where: { $0.identifier == windowIdentifier && $0.isVisible })
    else { return }
    guide.makeKey()
  }

  /// After the user grants Accessibility in System Settings, bring them back to try it.
  static func bringGuideToFront() {
    guard let guide = NSApp.windows.first(where: { $0.identifier == windowIdentifier && $0.isVisible })
    else { return }
    NSApp.activate(ignoringOtherApps: true)
    guide.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: OnboardingMetrics.windowSize),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = NSLocalizedString("onboarding_menu", comment: "")
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    // The SwiftUI root draws the shelf's glass; the window itself stays clear.
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isMovableByWindowBackground = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    // A titled window adds the title bar on top of contentRect; the glass is drawn edge
    // to edge (full-size content), so pin the frame itself to the guide's size.
    window.setFrame(NSRect(origin: .zero, size: OnboardingMetrics.windowSize), display: false)
    window.identifier = Self.windowIdentifier
    window.isReleasedWhenClosed = false
    window.delegate = self
    self.window = window
    return window
  }

  private func finish(launchAtLogin: Bool) {
    if !RuntimeEnvironment.isTesting, LaunchAtLogin.isEnabled != launchAtLogin {
      LaunchAtLogin.isEnabled = launchAtLogin
    }
    AppState.shared.switchShelf(to: .clipboard)
    Defaults[.hasSeenOnboarding] = true
    window?.close()
  }
}
