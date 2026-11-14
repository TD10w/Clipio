import AppKit

struct Accessibility {
  /// Clipio only needs to post ⌘V. That is the "post event" permission, which macOS lists
  /// under Accessibility. The sandbox blocks the AX prompt
  /// (`AXIsProcessTrustedWithOptions`): tccd answers "does not allow prompting", so the
  /// app was never added to the list. `CGRequestPostEventAccess` is the sandbox-safe request.
  static var isTrusted: Bool {
    CGPreflightPostEventAccess() || AXIsProcessTrusted()
  }

  /// Returns whether paste is allowed. If not, macOS shows its own prompt and adds Clipio
  /// to the list in System Settings.
  static func requestTrust() -> Bool {
    if isTrusted { return true }
    return CGRequestPostEventAccess()
  }

  static func explainMissingPermission() {
    // Let the shelf finish its existing close animation before presenting the explanation.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      guard NSApp.alertWindow == nil else {
        return
      }

      let alert = NSAlert()
      alert.alertStyle = .informational
      alert.messageText = "Allow Clipio to Paste"
      alert.informativeText = "The clip is already copied. You can paste it manually, or allow Clipio in System Settings so it can press Command-V for you."
      alert.addButton(withTitle: "Open System Settings")
      alert.addButton(withTitle: "Not Now")

      if alert.runModal() == .alertFirstButtonReturn,
         let settingsURL = URL(
           string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
         ) {
        NSWorkspace.shared.open(settingsURL)
      }
    }
  }
}
