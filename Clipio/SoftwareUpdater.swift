import Sparkle

@Observable
final class SoftwareUpdater {
  static let shared = SoftwareUpdater()

  private(set) var isConfigured = false
  private(set) var canCheckForUpdates = false
  var automaticallyChecksForUpdates = false {
    didSet {
      guard let updater = controller?.updater,
            updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates else { return }
      updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }
  }

  @ObservationIgnored private var controller: SPUStandardUpdaterController?
  @ObservationIgnored private var observations: [NSKeyValueObservation] = []

  private init() {}

  /// Called once after application startup, rather than when Settings is opened.
  func start() {
    #if DEBUG
    let isDebug = true
    #else
    let isDebug = false
    #endif
    guard controller == nil,
          UpdateConfiguration.isEnabled(
            info: Bundle.main.infoDictionary ?? [:],
            isDebug: isDebug,
            isTesting: RuntimeEnvironment.isTesting
          ) else { return }

    let controller = SPUStandardUpdaterController(
      startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
    )
    self.controller = controller
    isConfigured = true
    let updater = controller.updater
    observations = [
      updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
        self?.canCheckForUpdates = updater.canCheckForUpdates
      },
      updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
        self?.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
      }
    ]
    controller.startUpdater()
  }

  func checkForUpdates() {
    guard canCheckForUpdates else { return }
    controller?.checkForUpdates(nil)
  }
}
