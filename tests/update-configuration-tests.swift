import Foundation

@main
struct UpdateConfigurationTests {
  static func main() {
    let key = Data(repeating: 7, count: 32).base64EncodedString()
    let valid: [String: Any] = ["SUFeedURL": "https://github.com/TD10w/Clipio/releases/download/clipio-updates/appcast.xml", "SUPublicEDKey": key]
    func enabled(_ info: [String: Any], debug: Bool = false, testing: Bool = false) -> Bool {
      UpdateConfiguration.isEnabled(info: info, isDebug: debug, isTesting: testing)
    }
    precondition(enabled(valid))
    precondition(!enabled(valid, debug: true))
    precondition(!enabled(valid, testing: true))
    precondition(!enabled([:]))
    precondition(!enabled(["SUFeedURL": valid["SUFeedURL"]!]))
    for url in ["http://example.com/feed", "https:///feed", "https://user:pass@example.com/feed", "https://example.com/feed#fragment", "https://example.com/feed?token=x", "https://example.com/a b", "$(CLIPIO_UPDATE_FEED_URL)"] {
      precondition(!enabled(["SUFeedURL": url, "SUPublicEDKey": key]), url)
    }
    for invalidKey in ["", "not a key", Data(repeating: 0, count: 31).base64EncodedString()] {
      precondition(!enabled(["SUFeedURL": valid["SUFeedURL"]!, "SUPublicEDKey": invalidKey]))
    }
    print("Update configuration tests passed")
  }
}
