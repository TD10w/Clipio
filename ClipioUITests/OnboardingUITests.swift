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
      "-hasSeenOnboarding", "false", "-onboardingCloseCount", "0", "-pasteByDefault", "false",
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

  func testFirstLaunchShowsShortcutStepAndGatesPractice() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    XCTAssertTrue(guide.staticTexts["Open Clipio with one shortcut"].exists)
    XCTAssertEqual(shortcutText, "⌃⌥⇧⌘J")
    XCTAssertFalse(guide.buttons["onboarding-back"].isEnabled)
    capture("01-shortcut")

    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.staticTexts["Try it once"].exists)
    XCTAssertTrue(guide.staticTexts["Press ⌃⌥⇧⌘J to open your clipboard"].exists)
    XCTAssertFalse(guide.buttons["onboarding-next"].isEnabled, "Practice must be done (or skipped) before Next")
    guide.buttons["onboarding-back"].click()
    XCTAssertTrue(guide.staticTexts["Open Clipio with one shortcut"].exists)
  }

  func testPracticeOpensShelfAndPastesIntoGuide() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    guide.buttons["onboarding-next"].click()
    guide.buttons["onboarding-copy-sample"].click()
    app.typeKey("j", modifierFlags: [.command, .shift, .option, .control])
    XCTAssertTrue(app.descendants(matching: .any)["copy-history-item"].firstMatch.waitForExistence(timeout: 5))
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(guide.waitForExistence(timeout: 3))
    app.typeKey("v", modifierFlags: .command)
    let field = guide.textFields["onboarding-paste-field"]
    XCTAssertTrue(field.waitForExistence(timeout: 3))
    let pasted = NSPredicate(format: "value == %@", "Hello from Clipio 👋")
    wait(for: [XCTNSPredicateExpectation(predicate: pasted, object: field)], timeout: 5)
    XCTAssertTrue(guide.buttons["onboarding-next"].isEnabled)
    capture("02-practice-done")
  }

  func testSkipGoesToFinishAndFinishDoesNotReappear() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    guide.buttons["onboarding-skip"].click()
    XCTAssertTrue(guide.staticTexts["You're all set"].exists)
    XCTAssertTrue(guide.checkBoxes["onboarding-launch-at-login"].exists)
    capture("05-finish")

    guide.buttons["onboarding-back"].click()
    XCTAssertTrue(guide.staticTexts["Collection, for files"].exists)
    guide.buttons["onboarding-back"].click()
    XCTAssertTrue(guide.staticTexts["Skip the ⌘V"].exists)
    capture("03-autopaste")
    guide.buttons["onboarding-not-now"].click()
    XCTAssertTrue(guide.staticTexts["Collection, for files"].exists)
    guide.buttons["onboarding-next"].click()
    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))

    relaunchWithoutSeenOverride()
    XCTAssertFalse(guide.exists)
    settingsMenu.click()
    app.menuItems["Getting Started"].click()
    XCTAssertTrue(guide.waitForExistence(timeout: 3))
    XCTAssertTrue(guide.staticTexts["Open Clipio with one shortcut"].exists)
  }

  func testClosingMidwayShowsGuideOnceMore() {
    resetPersistedOnboardingState()
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    guide.buttons[XCUIIdentifierCloseWindow].click()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))

    removeOnboardingOverrides()
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5), "A mid-way close offers the guide again")
    guide.buttons[XCUIIdentifierCloseWindow].click()
    XCTAssertTrue(guide.waitForNonExistence(timeout: 3))

    app.terminate()
    launch()
    openShelf()
    XCTAssertFalse(guide.exists, "Closed twice: stop showing it automatically")
  }

  func testUnsetShortcutAndDarkAppearance() {
    let popupIndex = app.launchArguments.firstIndex(of: "-KeyboardShortcuts_popup")!
    app.launchArguments[popupIndex + 1] = "null"
    let appearanceIndex = app.launchArguments.firstIndex(of: "-appearanceMode")!
    app.launchArguments[appearanceIndex + 1] = "dark"
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    XCTAssertEqual(shortcutText, "Not set")
    capture("06-unset-dark")
    guide.buttons["onboarding-next"].click()
    XCTAssertTrue(guide.staticTexts["Click the Clipio icon in the menu bar"].exists)
    capture("07-practice-dark")
  }

  func testKeyboardNavigationStaysInGuide() {
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    app.typeKey(.return, modifierFlags: [])
    XCTAssertTrue(guide.staticTexts["Try it once"].waitForExistence(timeout: 2))
    app.typeKey(.escape, modifierFlags: [])
    XCTAssertTrue(guide.staticTexts["You're all set"].waitForExistence(timeout: 2))
    XCTAssertTrue(guide.exists)
  }

  func testGettingStartedFromSettings() {
    app.launchArguments += ["-menuIcon", "scissors"]
    launch()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    guide.buttons[XCUIIdentifierCloseWindow].click()
    openShelf()
    settingsMenu.click()
    app.menuItems["Preferences…"].click()
    activateBuiltApp()
    let button = app.buttons["settings-onboarding"]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    button.click()
    XCTAssertTrue(guide.waitForExistence(timeout: 5))
    XCTAssertTrue(guide.staticTexts["Open Clipio with one shortcut"].exists)

    guide.buttons["onboarding-skip"].click()
    capture("08-finish-scissors")
  }

  private func launch() {
    app.launch()
    activateBuiltApp()
  }

  /// Earlier tests may have finished the guide in the test app's own defaults domain.
  private func resetPersistedOnboardingState() {
    let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Clipio.app")
    guard let identifier = Bundle(url: url)?.bundleIdentifier else { return }
    for key in ["hasSeenOnboarding", "onboardingCloseCount"] {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
      process.arguments = ["delete", identifier, key]
      try? process.run()
      process.waitUntilExit()
    }
  }

  private func removeOnboardingOverrides() {
    app.terminate()
    for key in ["-hasSeenOnboarding", "-onboardingCloseCount"] {
      if let index = app.launchArguments.firstIndex(of: key) {
        app.launchArguments.removeSubrange(index...(index + 1))
      }
    }
  }

  private func relaunchWithoutSeenOverride() {
    removeOnboardingOverrides()
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
