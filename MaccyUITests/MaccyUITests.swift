import Carbon
import XCTest

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class MaccyUITests: XCTestCase {
  let app = XCUIApplication()
  let pasteboard = NSPasteboard(name: .init("com.clipio.ui-tests"))
  var generalPasteboardChangeCount = 0

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
    generalPasteboardChangeCount = NSPasteboard.general.changeCount
    pasteboard.clearContents()

    try? "Hello world".write(to: file1, atomically: true, encoding: .utf8)
    try? "Hello world".write(to: file2, atomically: true, encoding: .utf8)

    app.launchArguments.append("enable-testing")
    app.launchArguments.append("enable-ui-testing")
    app.launchArguments.append("open-ui-testing-shelf")
    app.launchArguments.append(contentsOf: ["-pasteByDefault", "false"])
    app.launchEnvironment["CLIPIO_UI_TEST_MODE"] = "1"
    app.launchEnvironment["CLIPIO_UI_TEST_OLDER_ITEM"] = copy2
    app.launchEnvironment["CLIPIO_UI_TEST_NEWER_ITEM"] = copy1
    app.launch()

    // Confirm both synthetic fixtures were captured before each test begins.
    XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 5))
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
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
    usleep(500_000)
    super.tearDown()
  }

  func testPopupWithHotkey() throws {
    popUpWithHotkey()
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testCloseWithEscape() throws {
    popUpWithMouse()
    assertExists(item(labeled: copy1))
    app.typeKey(.escape, modifierFlags: [])
    assertNotExists(item(labeled: copy1))
  }

  func testPopupWithMenubar() {
    popUpWithMouse()
    assertExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testNewCopyIsAdded() {
    popUpWithMouse()
    let copy3 = UUID().uuidString
    copyToClipboard(copy3)
    assertExists(item(labeled: copy3))
    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    assertExists(item(labeled: copy2))
  }

  func testSearch() {
    popUpWithMouse()
    search(copy2SearchQuery)
    assertSearchFieldValue(copy2SearchQuery)
    assertExists(item(labeled: copy2))
    assertNotExists(item(labeled: copy1))
  }

  func testSearchFiles() {
    copyToClipboard(file2)
    copyToClipboard(file1)
    popUpWithMouse()
    search(file2.lastPathComponent)
    assertExists(item(labeled: file2.absoluteString.removingPercentEncoding!))
    assertNotExists(item(labeled: file1.absoluteString.removingPercentEncoding!))
  }

  func testCopyWithClick() {
    popUpWithMouse()
    item(labeled: copy2).click()
    assertPasteboardStringEquals(copy2)
  }

  func testCopyWithEnter() {
    popUpWithMouse()
    hover(item(labeled: copy2))
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testCopyWithCommandShortcut() {
    popUpWithMouse()
    app.typeKey("2", modifierFlags: [.command])
    assertPasteboardStringEquals(copy2)
  }

  func testSearchAndCopyWithCommandShortcut() {
    popUpWithMouse()
    search(copy2SearchQuery)
    app.typeKey("1", modifierFlags: [.command])
    assertPasteboardStringEquals(copy2)
  }

  func testCopyImage() {
    copyToClipboard(image2)
    copyToClipboard(image1)
    popUpWithMouse()
    items.allElementsBoundByIndex[1].click()
    assertPasteboardDataCountEquals(image2.tiffRepresentation!.count, forType: .tiff)
  }

  func testCopyFile() {
    copyToClipboard(file2)
    copyToClipboard(file1)
    popUpWithMouse()

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
    popUpWithMouse()
    XCTAssertEqual(itemTitles[0...1], ["foo", "bar"])

    item(labeled: "bar").click()
    assertPasteboardDataEquals(html2, forType: .html)
  }

  func testDownArrow() {
    popUpWithMouse()
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testUpArrow() {
    popUpWithMouse()
    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.upArrow, modifierFlags: [])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testControlJ() {
    popUpWithMouse()
    app.typeKey("j", modifierFlags: [.control])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy2)
  }

  func testControlK() {
    popUpWithMouse()
    app.typeKey("j", modifierFlags: [.control])
    app.typeKey("k", modifierFlags: [.control])
    app.typeKey(.enter, modifierFlags: [])
    assertPasteboardStringEquals(copy1)
  }

  func testDeleteEntry() {
    popUpWithMouse()
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(item(labeled: copy1))

  }

  func testDeleteEntryDuringSearch() {
    popUpWithMouse()
    search(copy2SearchQuery)
    app.typeKey(.delete, modifierFlags: [.option])
    assertNotExists(item(labeled: copy2))

    app.typeKey(.escape, modifierFlags: [])
    popUpWithMouse()
    assertNotExists(item(labeled: copy2))
  }

  func testClear() {
    popUpWithMouse()
    pin(copy2)
    app.buttons["clear-history"].click()
    confirmClear()
    popUpWithMouse()
    assertNotExists(item(labeled: copy1))
    assertExists(item(labeled: copy2))
  }

  func testClearDuringSearch() {
    popUpWithMouse()
    search(copy2SearchQuery)
    app.buttons["clear-history"].click()
    confirmClear()
    popUpWithMouse()
    assertNotExists(item(labeled: copy1))
    assertNotExists(item(labeled: copy2))
  }

  func testClearAll() {
    popUpWithMouse()
    pin(copy2)
    XCUIElement.perform(withKeyModifiers: [.shift]) {
      app.buttons["clear-history"].click()
    }
    confirmClear()
    popUpWithMouse()
    assertNotExists(item(labeled: copy1))
    assertNotExists(item(labeled: copy2))
  }

  func testPin() {
    popUpWithMouse()
    pin(copy2)
    XCTAssertEqual(itemTitles[0...1], [copy2, copy1])

  }

  func testPinDuringSearch() {
    popUpWithMouse()
    search(copy2SearchQuery)
    pin(copy2)
    assertSearchFieldValue("")
    XCTAssertEqual(itemTitles[0...1], [copy2, copy1])
  }

  func testUnpin() {
    popUpWithMouse()
    pin(copy2)
    pin(copy2)
    XCTAssertEqual(itemTitles[0...1], [copy1, copy2])
  }

  func testRemoveLastWordFromSearchWithControlW() {
    popUpWithMouse()
    search("foo bar")
    app.typeKey("w", modifierFlags: [.control])
    assertSearchFieldValue("foo ")
  }

  func testPasteSelectionIsSafelyIntercepted() {
    popUpWithMouse()
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

    popUpWithMouse()
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

    popUpWithMouse()
    assertNotExists(item(labeled: copy3))
    assertExists(item(labeled: copy4))
  }

  func testCreatesNewCopyOnEnterWhenSearchResultsAreEmpty() {
    popUpWithMouse()
    search("foo bar")
    app.typeKey(.return, modifierFlags: [])
    XCTAssertEqual(pasteboard.string(forType: .string), "foo bar")
    assertExists(item(labeled: "foo bar"))
  }

  func testOpenAndClose() throws {
    // Simulate the popup hotkey press (Cmd + Shift + C).
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    // Release the 'C' key but keep the popup open.
    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
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
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
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
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    cDown.flags = [.maskCommand, .maskShift]
    cDown.post(tap: .cghidEventTap)

    waitUntilPoppedUp()

    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
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
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
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
    popUpWithMouse()

    // Activating another app exercises the shelf's production resign-key close path.
    XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
    assertNotExists(item(labeled: copy1))

  }

  private func popUpWithHotkey() {
    simulatePopupHotkey()
    waitUntilPoppedUp()
  }

  private func popUpWithMouse() {
    waitUntilPoppedUp()
  }

  private func simulatePopupHotkey() {
    let commandDown = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: true)!
    let commandUp = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false)!
    let shiftDown = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: true)!
    let shiftUp = CGEvent(
      keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Shift), keyDown: false)!
    shiftDown.flags = [.maskCommand]
    shiftUp.flags = [.maskCommand]
    let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
    let cUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
    cDown.flags = [.maskCommand, .maskShift]
    cUp.flags = [.maskCommand, .maskShift]
    commandDown.post(tap: .cghidEventTap)
    shiftDown.post(tap: .cghidEventTap)
    cDown.post(tap: .cghidEventTap)
    cUp.post(tap: .cghidEventTap)
    shiftUp.post(tap: .cghidEventTap)
    commandUp.post(tap: .cghidEventTap)
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
    usleep(20000)
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
    let button = app.dialogs.firstMatch.buttons.firstMatch
    expectation(for: NSPredicate(format: "isHittable = 1"), evaluatedWith: button)
    waitForExpectations(timeout: 3)
    button.click()
  }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
