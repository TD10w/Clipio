import Foundation

enum RuntimeEnvironment {
  static var isTesting: Bool {
    CommandLine.arguments.contains("enable-testing")
  }
}
