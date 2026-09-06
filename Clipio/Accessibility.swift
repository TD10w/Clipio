import AppKit

struct Accessibility {
  static func requestTrust() -> Bool {
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
    ] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
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
