import AppKit.NSRunningApplication
import Defaults
import KeyboardShortcuts
import Observation

enum PopupState {
  // Default; shortcut will toggle the popup
  case toggle
  // In this mode, every additional press of the main key
  // will cycle to the next item in the paste history list.
  // Releasing the modifier keys will accept selection and close the popup
  case cycle
  // Transition state when the shortcut is first pressed and
  // we don't know whether we are in "toggle" or "cycle" mode.
  case opening
}

@Observable
class Popup {
  static let verticalSeparatorPadding = 6.0
  static let horizontalSeparatorPadding = 6.0
  static let verticalPadding: CGFloat = 5
  static let horizontalPadding: CGFloat = 5

  // Radius used for items inset by the padding. Ensures they visually have the same curvature
  // as the menu.
  static let cornerRadius: CGFloat = if #available(macOS 26.0, *) {
    7
  } else {
    4
  }

  static let itemHeight: CGFloat = if #available(macOS 26.0, *) {
    24
  } else {
    22
  }

  var needsResize = false
  var height: CGFloat = 0
  var headerHeight: CGFloat = 0
  var extraTopHeight: CGFloat = 0
  var extraBottomHeight: CGFloat = 0
  var footerHeight: CGFloat = 0

  private var eventsMonitor: Any?

  private var state: PopupState = .toggle

  init() {
    guard !RuntimeEnvironment.isUnitTesting else { return }
    KeyboardShortcuts.onKeyDown(for: .popup) { [weak self] in self?.toggle(mode: .clipboard) }
    KeyboardShortcuts.onKeyDown(for: .collectionPopup) { [weak self] in self?.toggle(mode: .collection) }
    initEventsMonitor()
  }

  deinit {
    deinitEventsMonitor()
  }

  func initEventsMonitor() {
    guard eventsMonitor == nil else { return }

    self.eventsMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.flagsChanged, .keyDown],
      handler: handleEvent
    )
  }

  func deinitEventsMonitor() {
    guard let eventsMonitor else { return }

    NSEvent.removeMonitor(eventsMonitor)
  }

  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    AppState.shared.appDelegate?.panel.open(height: height, at: popupPosition)
  }

  func reset() {
    state = .toggle
    KeyboardShortcuts.enable(.popup)
    KeyboardShortcuts.enable(.collectionPopup)
  }

  func close() {
    AppState.shared.appDelegate?.panel.close()  // close() calls reset
  }

  func isClosed() -> Bool {
    AppState.shared.appDelegate?.panel.isPresented != true
  }

  func preferredHeight(for newHeight: CGFloat) -> CGFloat {
    var height = newHeight

    let minimumHeight = headerHeight + Self.verticalPadding

    height = max(height, minimumHeight)
    height = min(height, Defaults[.windowSize].height)
    return height
  }

  func resize(height: CGFloat) {
    self.height = height + headerHeight + extraTopHeight + extraBottomHeight + footerHeight
    AppState.shared.appDelegate?.panel.verticallyResize(to: preferredHeight(for: self.height))
    needsResize = false
  }

  func prepareToOpen() {
    KeyboardShortcuts.disable(.popup)
    KeyboardShortcuts.disable(.collectionPopup)
    state = .opening
  }

  func toggle(mode: ShelfMode) {
    let appState = AppState.shared
    if !isClosed(), appState.shelfMode == mode {
      close()
      return
    }
    appState.switchShelf(to: mode)
    if isClosed() { open(height: height) }
  }

  static func migrateLegacyDefaultShortcut() {
    let previousDefault = KeyboardShortcuts.Shortcut(.c, modifiers: [.command, .shift])
    if KeyboardShortcuts.Name.popup.shortcut == previousDefault {
      KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .shift]), for: .popup)
    }
  }

  static func isShelfSwitch(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, composing: Bool) -> Bool {
    let relevant = modifiers.intersection([.command, .option, .control, .shift])
    return keyCode == 48 && relevant.isEmpty && !composing
  }

  private func handleEvent(_ event: NSEvent) -> NSEvent? {
    switch event.type {
    case .keyDown:
      return handleKeyDown(event)
    case .flagsChanged:
      return handleFlagsChanged(event)
    default:
      return event
    }
  }

  private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
    let appState = AppState.shared
    guard let panel = appState.appDelegate?.panel, panel.isPresented,
          NSApp.keyWindow === panel else { return event }
    let composing = (panel.firstResponder as? NSTextInputClient)?.hasMarkedText() == true
    if Self.isShelfSwitch(keyCode: event.keyCode, modifiers: event.modifierFlags, composing: composing),
       !appState.collection.isExporting {
      appState.switchShelf(to: appState.shelfMode.other)
      return nil
    }
    if !composing, event.keyCode == 53 {
      close()
      return nil
    }
    if !composing, appState.shelfMode == .collection {
      switch KeyChord(event) {
      case .deleteCurrentItem:
        Task { @MainActor in appState.deleteSelection() }
        return nil
      case .pinOrUnpin:
        Task { @MainActor in appState.togglePin() }
        return nil
      case .selectCurrentItem:
        Task { @MainActor in appState.select() }
        return nil
      case .moveToNext:
        appState.collection.moveSelection(by: 1)
        return nil
      case .moveToPrevious:
        appState.collection.moveSelection(by: -1)
        return nil
      default: break
      }
    }
    for (name, mode) in [(KeyboardShortcuts.Name.popup, ShelfMode.clipboard), (.collectionPopup, .collection)] {
      if let shortcut = name.shortcut,
         shortcut.key?.rawValue == Int(event.keyCode),
         event.modifierFlags.intersection([.command, .shift, .option, .control]) == shortcut.modifiers {
        toggle(mode: mode)
        return nil
      }
    }
    return event
  }

  private func handleFlagsChanged(_ event: NSEvent) -> NSEvent? {
    // If we are in cycle mode, releasing modifiers triggers a selection
    if state == .cycle && allModifiersReleased(event) {
      DispatchQueue.main.async {
        AppState.shared.select()
      }
      return nil
    }

    // Otherwise if in opening mode, enter toggle mode
    if state == .opening && allModifiersReleased(event) {
      state = .toggle
      return event
    }

    return event
  }

  private func allModifiersReleased(_ event: NSEvent) -> Bool {
    return event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask)
  }
}
