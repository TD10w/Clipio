import AppKit

struct RuntimeEnvironment {
  static let current = RuntimeEnvironment(
    arguments: CommandLine.arguments,
    environment: ProcessInfo.processInfo.environment
  )
  static let uiTestPasteboardName = NSPasteboard.Name("com.clipio.ui-tests")

  let arguments: [String]
  let environment: [String: String]

  init(arguments: [String], environment: [String: String] = [:]) {
    self.arguments = arguments
    self.environment = environment
  }

  var isUITesting: Bool {
    arguments.contains("enable-ui-testing") || environment["CLIPIO_UI_TEST_MODE"] == "1"
  }
  var isUnitTesting: Bool { arguments.contains("enable-testing") && !isUITesting }
  var isTesting: Bool { isUnitTesting || isUITesting }
  var usesInMemoryStorage: Bool { isTesting }
  var skipsApplicationStartup: Bool { isUnitTesting }

  static var isUITesting: Bool { current.isUITesting }
  static var isUnitTesting: Bool { current.isUnitTesting }
  static var isTesting: Bool { current.isTesting }
  static var usesInMemoryStorage: Bool { current.usesInMemoryStorage }
  static var skipsApplicationStartup: Bool { current.skipsApplicationStartup }
}
