import AppKit.NSSound

extension NSSound {
  static let collectionReceipt: NSSound? = Bundle.main.url(forResource: "Collect", withExtension: "wav")
    .flatMap { NSSound(contentsOf: $0, byReference: false) }
  static let knock = NSSound(
    contentsOf: Bundle.main.url(forResource: "Knock", withExtension: "caf")!, byReference: true)
  static let write = NSSound(
    contentsOf: Bundle.main.url(forResource: "Write", withExtension: "caf")!, byReference: true)
}
