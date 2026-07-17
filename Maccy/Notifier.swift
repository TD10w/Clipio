import AppKit

enum Notifier {
  static func play(
    sound: NSSound?,
    player: (NSSound) -> Bool = { $0.play() }
  ) {
    guard let sound else {
      return
    }

    _ = player(sound)
  }
}
