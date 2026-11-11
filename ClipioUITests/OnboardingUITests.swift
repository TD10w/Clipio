import Carbon
import XCTest

final class OnboardingUITests: XCTestCase {
  private let app = XCUIApplication()
  private var settingsMenu: XCUIElement { app.descendants(matching: .any)["shelf-settings-menu"].firstMatch }
  private var guide: XCUIElement { app.windows["clipio-onboarding"] }
  private var shortcutText: String { guide.staticTexts["onboarding-shortcut"].value as? String ?? "" }

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app.launchArguments = [
      "enable-testing", "enable-ui-testing", "show-ui-testing-onboarding",
      "-hasSeenOnboarding", "false", "-pasteByDefault", "false",
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-appearanceMode", "light",
      "-KeyboardShortcuts_popup",
      #""{\"carbonKeyCode\":\#(kVK_ANSI_J),\"carbonModifiers\":\#(cmdKey | shiftKey | controlKey | optionKey)}""#,
      "-KeyboardShortcuts_collectionPopup",
      #""{\"carbonKeyCode\":\#(kVK_ANSI_K),\"carbonModifiers\":\#(cmdKey | shiftKey | controlKey | optionKey)}""#
    ]
    app.launchEnvironment["CLIPIO_UI_TEST_NEWER_ITEM"] = "Synthetic onboarding clip"
    app.launchEnvironment["CLIPIO_UI_TEST_MODE"] = "1"
  }

  override func tearDown() {
    app.terminate()
    super.tearDown()
  }

  func testFirstLaunchNavigationAndCompletionOpensClipboard() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    XCTAssertTrue(guide.staticTexts["Find Clipio here"].exists)
    XCTAssertFalse(guide.buttons["onboarding-back"].isEnabled)
    capture("01-entry")

    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.staticTexts["Clipboard"].exists)
    XCTAssertEqual(shortcutText, "⌃⌥⇧⌘J")
    capture("02-clipboard")
    guide.buttons["onboarding-back"].click()
    XCTAssertTrue(guide.staticTexts["Find Clipio here"].exists)
    guide.buttons["onboarding-next"].click()
    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.staticTexts["Collection"].exists)
    XCTAssertEqual(shortcutText, "⌃⌥⇧⌘K")
    capture("03-collection")
    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["copy-history-item"].firstMatch.waitForExistence(timeout: 5))

    relaunchWithoutSeenOverride()
    XCTAssertFalse(guide.exists)
    openShelf()
    settingsMenu.click()
    app.menuItems["Getting Started"].click()
    XCTAssertTrue(guide.waitForExistence(timeout: 3))
    XCTAssertTrue(guide.staticTexts["Find Clipio here"].exists)
  }

  func testSkipDoesNotAutomaticallyReappear() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    guide.buttons["onboarding-skip"].click()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))
    relaunchWithoutSeenOverride()
    XCTAssertFalse(guide.exists)
  }

  func testWindowCloseDoesNotAutomaticallyReappear() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    guide.buttons[XCUIIdentifierCloseWindow].click()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))
    relaunchWithoutSeenOverride()
    XCTAssertFalse(guide.exists)
  }

  func testUnsetShortcutAndDarkAppearance() {
    let popupIndex = app.launchArguments.firstIndex(of: "-KeyboardShortcuts_popup")!
    app.launchArguments[popupIndex + 1] = "null"
    let appearanceIndex = app.launchArguments.firstIndex(of: "-appearanceMode")!
    app.launchArguments[appearanceIndex + 1] = "dark"
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    capture("04-entry-dark")
    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.staticTexts["Not set. You can change shortcuts in Settings."].exists)
    capture("05-unset-dark")
    guide.buttons["onboarding-next"].click()
    capture("06-collection-dark")
  }

  func testKeyboardNavigationStaysInGuide() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    app.typeKey(.tab, modifierFlags: [])
    XCTAssertTrue(guide.staticTexts["Find Clipio here"].exists)
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(guide.staticTexts["Clipboard"].exists)
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))
  }

  func testGettingStartedFromSettings() {
    app.launchArguments += ["-menuIcon", "scissors"]
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    capture("07-scissors-icon")
    guide.buttons["onboarding-skip"].click()
    openShelf()
    settingsMenu.click()
    app.menuItems["Preferences…"].click()
    activateBuiltApp()
    let button = app.buttons["settings-onboarding"]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: app.windows["General"].screenshot())
    attachment.name = "08-general-settings"
    attachment.lifetime = .keepAlways
    add(attachment)
    button.click()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    XCTAssertTrue(guide.staticTexts["Find Clipio here"].exists)
  }

  private func launch() {
    app.launch()
    activateBuiltApp()
  }

  private func relaunchWithoutSeenOverride() {
    app.terminate()
    let index = app.launchArguments.firstIndex(of: "-hasSeenOnboarding")!
    app.launchArguments.removeSubrange(index...(index + 1))
    launch()
    // Wait for startup/prewarming before asserting absence of an automatic window.
    openShelf()
    XCTAssertTrue(settingsMenu.waitForExistence(timeout: 5))
  }

  private func activateBuiltApp() {
    let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Clipio.app")
    if let identifier = Bundle(url: url)?.bundleIdentifier {
      NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first?.activate()
    }
  }

  private func openShelf() {
    if settingsMenu.exists { return }
    let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Clipio.app")
    let opened = expectation(description: "Open isolated shelf")
    NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
      XCTAssertNil(error)
      opened.fulfill()
    }
    wait(for: [opened], timeout: 5)
    activateBuiltApp()
    XCTAssertTrue(settingsMenu.waitForExistence(timeout: 5))
  }

  private func capture(_ name: String) {
    let screenshot = guide.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
