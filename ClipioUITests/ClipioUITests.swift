import Carbon
import XCTest

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class ClipioUITests: XCTestCase {
  let app = XCUIApplication()
  let pasteboard = NSPasteboard(name: .init("com.clipio.ui-tests"))
  var generalPasteboardChangeCount = 0
  private var originalInputSource: TISInputSource?

  let copy1 = UUID().uuidString
  let copy2 = UUID().uuidString
  let copy3 = UUID().uuidString

  var copy2SearchQuery: String {
    for length in 1...8 {
      let query = String(copy2.prefix(length))
      if !copy1.localizedCaseInsensitiveContains(query) {
        return query
      }
    }
    return copy2
  }

  // https://hetima.github.io/fucking_nsimage_syntax
  let image1 = NSImage(named: "NSAddTemplate")!
  let image2 = NSImage(named: "NSBluetoothTemplate")!

  let file1 = URL.applicationSupportDirectory.appendingPathComponent("file1.txt")
  let file2 = URL.applicationSupportDirectory.appendingPathComponent("file2.txt")

  let rtf1 = NSAttributedString(string: "foo").rtf(
    from: NSRange(0...2),
    documentAttributes: [:]
  )
  let rtf2 = NSAttributedString(string: "bar").rtf(
    from: NSRange(0...2),
    documentAttributes: [:]
  )

  let html1 = "<a href='#'>foo</a>".data(using: .utf8)
  let html2 = "<a href='#'>bar</a>".data(using: .utf8)

  var items: XCUIElementQuery {
    app.descendants(matching: .any).matching(identifier: "copy-history-item")
  }

  private func item(labeled label: String) -> XCUIElement {
    items.matching(NSPredicate(format: "label == %@", label)).firstMatch
  }

  var itemTitles: [String] {
    items.allElementsBoundByIndex
      .sorted(by: { $0.frame.origin.x < $1.frame.origin.x })
      .compactMap { $0.value as? String }
  }

  override func setUp() {
    super.setUp()

    continueAfterFailure = false
    originalInputSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let asciiSource = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
    XCTAssertEqual(TISSelectInputSource(asciiSource), noErr)
    generalPasteboardChangeCount = NSPasteboard.general.changeCount
    pasteboard.clearContents()

    try? "Hello world".write(to: file1, atomically: true, encoding: .utf8)
    try? "Hello world".write(to: file2, atomically: true, encoding: .utf8)

    app.launchArguments.append("enable-testing")
    app.launchArguments.append("enable-ui-testing")
    app.launchArguments.append(contentsOf: ["-pasteByDefault", "false"])
    // Keep the test hotkey separate from the owner's installed clipboard manager.
    app.launchArguments.append(contentsOf: [
      "-KeyboardShortcuts_popup",
      #""{\"carbonKeyCode\":\#(kVK_ANSI_J),\"carbonModifiers\":\#(cmdKey | shiftKey | controlKey | optionKey)}""#
    ])
    app.launchArguments.append(contentsOf: [
      "-KeyboardShortcuts_collectionPopup",
      #""{\"carbonKeyCode\":\#(kVK_ANSI_K),\"carbonModifiers\":\#(cmdKey | shiftKey | controlKey | optionKey)}""#
    ])
    app.launchEnvironment["CLIPIO_UI_TEST_COLLECTION_FIXTURE"] = "1"
    app.launchEnvironment["CLIPIO_UI_TEST_MODE"] = "1"
    app.launchEnvironment["CLIPIO_UI_TEST_OLDER_ITEM"] = copy2
    app.launchEnvironment["CLIPIO_UI_TEST_NEWER_ITEM"] = copy1
    app.launch()
  }

  override func tearDown() {
    app.terminate()
    XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    pasteboard.clearContents()
    XCTAssertEqual(
      NSPasteboard.general.changeCount,
      generalPasteboardChangeCount,
      "UI tests must never read from or write to the personal clipboard"
    )
    if let originalInputSource { TISSelectInputSource(originalInputSource) }
    usleep(500_000)
    super.tearDown()
  }

  func testPopupWithHotkey() throws {
    popUpWithHotkey()
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testCloseWithEscape() throws {
    openShelf()
    assertExists(item(labeled: copy1))
    app.typeKey(.escape, modifierFlags: [])
    assertNotExists(item(labeled: copy1))
  }

  func testPopupWithMenubar() throws {
    let statusItem = app.statusItems.firstMatch
    guard statusItem.waitForExistence(timeout: 3), statusItem.isHittable else {
      throw XCTSkip("XCTest cannot access this session's menu extras")
    }
    statusItem.click()
    waitUntilPoppedUp()
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testPopupWithApplicationReopen() {
    openShelf()
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testNewCopyIsAdded() {
    openShelf()
    let copy3 = UUID().uuidString
    copyToClipboard(copy3)
    assertExists(item(labeled: copy3))
    app.typeKey(.escape, modifierFlags: [])
    openShelf()
    assertExists(item(labeled: copy2))
  }

  func testSearch() {
    // Numeric fixtures avoid composing text through the user's active input method.
    let matchingText = "222222222"
    let otherText = "111111111"
    copyToClipboard(otherText)
    copyToClipboard(matchingText)
    openShelf()
    search(matchingText)
    assertSearchFieldValue(matchingText)
    assertExists(item(labeled: matchingText))
    XCTAssertTrue(item(labeled: matchingText).isHittable)
    assertNotVisible(item(labeled: otherText))
  }

  func testSearchFiles() {
    copyToClipboard(file2)
    copyToClipboard(file1)
    openShelf()
    search(file2.lastPathComponent)
    assertExists(item(labeled: file2.absoluteString.removingPercentEncoding!))
    assertNotExists(item(labeled: file1.absoluteString.removingPercentEncoding!))
  }

  func testCopyWithClick() {
    openShelf()
    item(labeled: copy2).click()
    assertPasteboardStringEquals(copy2)
  }

  func testCopyWithEnter() {
    openShelf()
    hover(item(labeled: copy2))
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testKeyboardSelectionAfterHover() {
    openShelf()
    hover(item(labeled: copy2))
    app.typeKey(.leftArrow, modifierFlags: [])
    expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: item(labeled: copy1))
    waitForExpectations(timeout: 3)
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testCopyWithCommandShortcut() {
    openShelf()
    app.typeKey("2", modifierFlags: [.command])
    assertPasteboardStringEquals(copy2)
  }

  func testSearchAndCopyWithCommandShortcut() {
    openShelf()
    search(copy2SearchQuery)
    app.typeKey("1", modifierFlags: [.command])
    assertPasteboardStringEquals(copy2)
  }

  func testCopyImage() {
    copyToClipboard(image2)
    copyToClipboard(image1)
    openShelf()
    items.allElementsBoundByIndex[1].click()
    assertPasteboardDataCountEquals(image2.tiffRepresentation!.count, forType: .tiff)
  }

  func testCopyFile() {
    copyToClipboard(file2)
    copyToClipboard(file1)
    openShelf()

    XCTAssertEqual(itemTitles[0...1], [
      file1.absoluteString.removingPercentEncoding!,
      file2.absoluteString.removingPercentEncoding!
    ])

    item(labeled: file2.absoluteString.removingPercentEncoding!).click()
    assertPasteboardStringEquals(file2.absoluteString, forType: .fileURL)
  }

  func testCopyRTF() {
    copyToClipboard(rtf2, .rtf)
    copyToClipboard(rtf1, .rtf)
    popUpWithHotkey()
    XCTAssertEqual(itemTitles[0...1], ["foo", "bar"])

    app.staticTexts["bar"].firstMatch.click()
    XCTAssertEqual(pasteboard.data(forType: .rtf), rtf2)
  }

  func testCopyHTML() {
    copyToClipboard(html2, .html)
    copyToClipboard(html1, .html)
    openShelf()
    XCTAssertEqual(itemTitles[0...1], ["foo", "bar"])

    item(labeled: "bar").click()
    assertPasteboardDataEquals(html2, forType: .html)
  }

  func testDownArrow() {
    openShelf()
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testUpArrow() {
    openShelf()
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.upArrow, modifierFlags: [])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testControlJ() {
    openShelf()
    app.typeKey("j", modifierFlags: [.control])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testControlK() {
    openShelf()
    app.typeKey("j", modifierFlags: [.control])
    app.typeKey("k", modifierFlags: [.control])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testDeleteEntry() {
    openShelf()
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(item(labeled: copy1))

  }

  func testDeleteEntryDuringSearch() {
    openShelf()
    search(copy2SearchQuery)
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(item(labeled: copy2))

    app.typeKey(.escape, modifierFlags: [])
    openShelf()
    assertNotExists(item(labeled: copy2))
  }

  func testClear() {
    openShelf()
    pin(copy2)
    app.buttons["clear-history"].click()
    confirmClear()
    openShelf()
    assertNotExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testClearDuringSearch() {
    openShelf()
    search(copy2SearchQuery)
    app.buttons["clear-history"].click()
    confirmClear()
    openShelf()
    assertNotExists(item(labeled: copy1))
    assertNotExists(item(labeled: copy2))
  }

  func testClearAll() {
    openShelf()
    pin(copy2)
    XCUIElement.perform(withKeyModifiers: [.shift]) {
      app.buttons["clear-history"].click()
    }
    confirmClear()
    openShelf()
    assertNotExists(item(labeled: copy1))
    assertNotExists(item(labeled: copy2))
  }

  func testPin() {
    openShelf()
    pin(copy2)
    XCTAssertEqual(itemTitles[0...1], [copy2, copy1])

  }

  func testPinDuringSearch() {
    openShelf()
    search(copy2SearchQuery)
    pin(copy2)
    assertSearchFieldValue("")
    XCTAssertEqual(itemTitles[0...1], [copy2, copy1])
  }

  func testUnpin() {
    openShelf()
    pin(copy2)
    XCTAssertEqual(itemTitles[0...1], [copy2, copy1])
    pin(copy2)
    XCTAssertEqual(itemTitles[0...1], [copy1, copy2])
  }

  func testRemoveLastWordFromSearchWithControlW() {
    openShelf()
    search("foo bar")
    app.typeKey("w", modifierFlags: [.control])
    assertSearchFieldValue("foo ")
  }

  func testPasteSelectionIsSafelyIntercepted() {
    openShelf()
    XCUIElement.perform(withKeyModifiers: [.option]) {
      item(labeled: copy2).click()
    }

    assertPasteboardStringEquals(copy2)
    assertPopupDismissed()
  }

  func testDisablesOnOptionClickingMenubarIcon() {
    XCUIElement.perform(withKeyModifiers: .option) {
      app.statusItems.firstMatch.click()
    }

    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)

    openShelf()
    assertNotExists(item(labeled: copy3))
    assertNotExists(item(labeled: copy4))

    app.typeKey(.escape, modifierFlags: [])
    XCUIElement.perform(withKeyModifiers: .option) {
      app.statusItems.firstMatch.click()
    }
  }

  func testDisablesOnlyForNextCopyOnOptionShiftClickingMenubarIcon() {
    XCUIElement.perform(withKeyModifiers: [.option, .shift]) {
      app.statusItems.firstMatch.click()
    }

    let copy3 = UUID().uuidString
    let copy4 = UUID().uuidString
    copyToClipboard(copy3)
    copyToClipboard(copy4)

    openShelf()
    assertNotExists(item(labeled: copy3))
    assertExists(item(labeled: copy4))
  }

  func testCreatesNewCopyOnEnterWhenSearchResultsAreEmpty() {
    openShelf()
    search("foo bar")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertEqual(pasteboard.string(forType: .string), "foo bar")
    assertExists(item(labeled: "foo bar"))
  }

  func testOpenAndClose() throws {
    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'C' key but keep the popup open.
    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: false)!
    cUp.flags = [.maskCommand, .maskShift]
    cUp.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'Shift' key and assert that the popup remains open - "normal" mode.
    let shiftUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    shiftUp.flags = [.maskCommand] // Command remains active, Shift released
    shiftUp.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'CMD' key and assert that the popup remains open - "normal" mode.
    let commandUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false)!
    commandUp.flags = []
    commandUp.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Press shortcut again and assert the window closes
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    assertPopupDismissed()
  }

  func testOpenAndSelectSecondItem() throws {
    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: false)!
    cUp.flags = [.maskCommand, .maskShift]
    cUp.post(tap: .cghidEventTap)

    // Press C 1 more time while keeping the modifier keys pressed
    cDown.post(tap: .cghidEventTap)

    // Release all modifiers keys and assert that the popup closes.
    let modifiersUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    modifiersUp.flags = []
    modifiersUp.post(tap: .cghidEventTap)

    assertPopupDismissed()
    assertPasteboardStringEquals(copy2)
  }

  func testOpenAndSelectThirdItem() throws {
    copyToClipboard(copy3)

    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: false)!
    cUp.flags = [.maskCommand, .maskShift]
    cUp.post(tap: .cghidEventTap)

    // Press C 2 more times while keeping the modifier keys pressed
    cDown.post(tap: .cghidEventTap)
    cUp.post(tap: .cghidEventTap)
    cDown.post(tap: .cghidEventTap)

    // Release all modifiers keys and assert that the popup closes.
    let modifiersUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    modifiersUp.flags = []
    modifiersUp.post(tap: .cghidEventTap)

    assertPopupDismissed()
    assertPasteboardStringEquals(copy2)
  }

  func testOpenAndSelectThirdItemRepeatedPress() throws {
    copyToClipboard(copy3)

    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_J), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Press C 2 more times while keeping the modifier keys pressed
    cDown.post(tap: .cghidEventTap)
    cDown.post(tap: .cghidEventTap)

    // Release all modifiers keys and assert that the popup closes.
    let modifiersUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    modifiersUp.flags = []
    modifiersUp.post(tap: .cghidEventTap)

    assertPopupDismissed()
    assertPasteboardStringEquals(copy2)
  }

  func testTogglePopupAndCloseOnClickOutside() {
    openShelf()

    // Activating another app exercises the shelf's production resign-key close path.
    XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
    assertNotExists(item(labeled: copy1))

  }

  func testCollectionSwitchIconAndTabFromSearch() {
    openShelf()
    search(copy2SearchQuery)
    app.buttons["switch-shelf"].click()
    let collected = app.descendants(matching: .any).matching(identifier: "collection-item").firstMatch
    assertExists(collected)
    let attachment = XCTAttachment(screenshot: app.dialogs.firstMatch.screenshot())
    attachment.name = "collection-provisional-shelf"
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTAssertEqual(app.textFields.firstMatch.value as? String, "")
    app.typeKey(.tab, modifierFlags: [])
    assertExists(item(labeled: copy2))
    assertSearchFieldValue(copy2SearchQuery)
    app.typeKey(.tab, modifierFlags: [])
    assertExists(collected)
  }

  func testCollectionHasSeparateShortcutAndClipboardShortcutRoutesBack() {
    openShelf()
    app.typeKey("k", modifierFlags: [.command, .shift, .control, .option])
    let collected = app.descendants(matching: .any).matching(identifier: "collection-item").firstMatch
    assertExists(collected)
    simulatePopupHotkey()
    assertExists(item(labeled: copy1))
    app.typeKey("k", modifierFlags: [.command, .shift, .control, .option])
    assertExists(collected)
    app.typeKey(.escape, modifierFlags: [])
    assertNotExists(collected)
  }

  func testCollectionClearKeepsPinnedItem() {
    openShelf()
    app.buttons["switch-shelf"].click()
    let collected = app.descendants(matching: .any).matching(identifier: "collection-item").firstMatch
    assertExists(collected)
    collected.click()
    collected.hover()
    let pin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "collection-pin-")).firstMatch
    assertExists(pin)
    pin.click()
    app.buttons["clear-collection"].click()
    confirmClear()
    assertExists(collected)
  }

  func testCollectionDeleteDoesNotDeleteClipboardHistory() {
    openShelf()
    app.buttons["switch-shelf"].click()
    let collected = app.descendants(matching: .any).matching(identifier: "collection-item").firstMatch
    assertExists(collected)
    collected.click()
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(collected)
    app.typeKey(.tab, modifierFlags: [])
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  private func popUpWithHotkey() {
    simulatePopupHotkey()
    waitUntilPoppedUp()
  }

  private func openShelf() {
    guard !items.firstMatch.exists || !items.firstMatch.isHittable else { return }

    // Reopen the exact built app, preserving isolation from the installed copy.
    let applicationURL = Bundle.main.bundleURL.deletingLastPathComponent()
      .appendingPathComponent("Clipio.app")
    let opened = expectation(description: "Reopen the test build of Clipio")
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { _, error in
      XCTAssertNil(error)
      opened.fulfill()
    }
    wait(for: [opened], timeout: 5)
    waitUntilPoppedUp()
  }

  private func simulatePopupHotkey() {
    app.typeKey("j", modifierFlags: [.command, .shift, .control, .option])
  }

  private func waitUntilPoppedUp() {
    if !items.firstMatch.waitForExistence(timeout: 3) {
      XCTFail("Clipio did not pop up")
    }
  }

  private func assertPopupDismissed() {
    if !items.firstMatch.waitForNonExistence(timeout: 3) {
      XCTFail("Clipio did not dismiss")
    }
  }

  private func copyToClipboard(_ content: String) {
    pasteboard.clearContents()
    pasteboard.setString(content, forType: .string)
    waitTillClipboardCheck()
  }

  private func copyToClipboard(_ content: NSImage) {
    pasteboard.clearContents()
    pasteboard.setData(content.tiffRepresentation, forType: .tiff)
    waitTillClipboardCheck()
  }

  private func copyToClipboard(_ content: URL) {
    pasteboard.clearContents()
    pasteboard.setData(content.dataRepresentation, forType: .fileURL)
    // WTF: The subsequent writes to pasteboard are not
    // visible unless we explicitly read the last one?!
    pasteboard.string(forType: .fileURL)
    waitTillClipboardCheck()
  }

  private func copyToClipboard(_ content: Data?, _ type: NSPasteboard.PasteboardType) {
    pasteboard.clearContents()
    pasteboard.setData(content, forType: type)
    waitTillClipboardCheck()
  }

  // Default interval for Maccy to check clipboard is 1 second
  private func waitTillClipboardCheck() {
    usleep(1_500_000)
  }

  private func pin(_ title: String) {
    hover(item(labeled: title))
    app.typeKey("p", modifierFlags: [.option])
    usleep(1_500_000)
  }

  private func hover(_ element: XCUIElement) {
    element.hover()
    expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func search(_ string: String) {
    app.textFields.firstMatch.click()
    app.textFields.firstMatch.typeText(string)
    waitForSearch()
  }

  private func waitForSearch() {
    // NOTE: This is a hack and is flaky.
    // Ideally we should wait for a proper condition to detect that search has settled down.
    usleep(500000)  // wait for search throttle
  }

  private func assertExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 1"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func assertNotExists(_ element: XCUIElement) {
    expectation(for: NSPredicate(format: "exists = 0"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func assertNotVisible(_ element: XCUIElement) {
    expectation(
      for: NSPredicate(format: "(exists = 0) || (isHittable = 0)"), evaluatedWith: element)
    waitForExpectations(timeout: 3)
  }

  private func assertPasteboardDataEquals(
    _ expected: Data?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let copy = object as? Data else {
        return false
      }

      return self.pasteboard.data(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }

  private func assertPasteboardDataCountEquals(
    _ expected: Int, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let count = object as? Int else {
        return false
      }

      return self.pasteboard.data(forType: forType)!.count == count
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }

  private func assertPasteboardStringEquals(
    _ expected: String?, forType: NSPasteboard.PasteboardType = .string
  ) {
    let predicate = NSPredicate { (object, _) -> Bool in
      guard let copy = object as? String else {
        return false
      }

      return self.pasteboard.string(forType: forType) == copy
    }
    expectation(for: predicate, evaluatedWith: expected)
    waitForExpectations(timeout: 3)
  }

  private func assertSearchFieldValue(_ string: String) {
    XCTAssertEqual(app.textFields.firstMatch.value as? String, string)
  }

  private func confirmClear() {
    let button = app.buttons.matching(NSPredicate(
      format: "identifier IN %@", ["confirm-clear-history", "confirm-clear-collection"]
    )).firstMatch
    expectation(for: NSPredicate(format: "isHittable = 1"), evaluatedWith: button)
    waitForExpectations(timeout: 3)
    button.click()
  }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
