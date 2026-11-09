import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let popup = Self("popup", default: Shortcut(.v, modifiers: [.command, .shift]))
  static let collectionPopup = Self("collectionPopup", default: Shortcut(.c, modifiers: [.command, .shift]))
  static let pin = Self("pin", default: Shortcut(.p, modifiers: [.option]))
  static let delete = Self("delete", default: Shortcut(.delete, modifiers: [.option]))
  static let togglePreview = Self("togglePreview", default: Shortcut(.space, modifiers: [.control]))
}
