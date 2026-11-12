import Foundation

/// Only distribution builds with a complete, explicit Clipio feed can start Sparkle.
struct UpdateConfiguration {
  static func isEnabled(info: [String: Any], isDebug: Bool, isTesting: Bool) -> Bool {
    guard !isDebug, !isTesting,
          let feed = info["SUFeedURL"] as? String,
          let url = URLComponents(string: feed),
          url.scheme == "https", let host = url.host, !host.isEmpty,
          url.user == nil, url.password == nil, url.fragment == nil, url.query == nil,
          feed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          let key = info["SUPublicEDKey"] as? String,
          let decoded = Data(base64Encoded: key), decoded.count == 32 else { return false }
    return true
  }
}
