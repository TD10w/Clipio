import Sauce
import Defaults
import SwiftUI

struct KeyHandlingView<Content: View>: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @ViewBuilder let content: () -> Content

  @Environment(AppState.self) private var appState

  var body: some View {
    content()
      .onKeyPress { _ in
        // Unfortunately, key presses don't allow access to
        // key code and don't properly work with multiple inputs,
        // so pressing ⌘, on non-English layout doesn't open
        // preferences. Stick to NSEvent to fix this behavior.

        if searchFocused {
          // Ignore input when candidate window is open
          // https://stackoverflow.com/questions/73677444/how-to-detect-the-candidate-window-when-using-japanese-keyboard
          if let inputClient = NSApp.keyWindow?.firstResponder as? NSTextInputClient,
             inputClient.hasMarkedText() {
            return .ignored
          }
        }

        if appState.shelfMode == .collection {
          return handleCollectionKey(KeyChord(NSApp.currentEvent))
        }

        switch KeyChord(NSApp.currentEvent) {
        case .clearHistory, .clearHistoryAll:
          let key = KeyChord(NSApp.currentEvent) == .clearHistoryAll ? "clear_all" : "clear"
          guard let item = appState.footer.items.first(where: { $0.title == key }) else { return .ignored }
          item.requestAction()
          return .handled
        case .clearSearch:
          searchQuery = ""
          return .handled
        case .deleteCurrentItem:
          appState.deleteSelection()
          return .handled
        case .deleteOneCharFromSearch:
          searchFocused = true
          _ = searchQuery.popLast()
          return .handled
        case .deleteLastWordFromSearch:
          searchFocused = true
          let newQuery = searchQuery.split(separator: " ").dropLast().joined(separator: " ")
          if newQuery.isEmpty {
            searchQuery = ""
          } else {
            searchQuery = "\(newQuery) "
          }

          return .handled
        case .moveToNext:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightNext()
          return .handled
        case .moveToLast:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightLast()
          return .handled
        case .moveToPrevious:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightPrevious()
          return .handled
        case .moveToFirst:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }

          appState.navigator.highlightFirst()
          return .handled
        case .extendToNext:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          return .ignored
        case .extendToLast:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          return .ignored
        case .extendToPrevious:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          return .ignored
        case .extendToFirst:
          guard NSApp.characterPickerWindow == nil else {
            return .ignored
          }
          return .ignored
        case .openPreferences:
          appState.openPreferences()
          return .handled
        case .pinOrUnpin:
          appState.togglePin()
          return .handled
        case .selectCurrentItem:
          appState.select()
          return .handled
        case .close:
          appState.popup.close()
          return .handled
        case .togglePreview:
          return .ignored
        default:
          ()
        }

        if let item = appState.history.pressedShortcutItem {
          appState.navigator.select(item: item)
          Task {
            try? await Task.sleep(for: .milliseconds(50))
            appState.history.select(item)
          }
          return .handled
        }

        return .ignored
      }
  }
  private func handleCollectionKey(_ chord: KeyChord) -> KeyPress.Result {
    let store = appState.collection
    switch chord {
    case .moveToNext: store.moveSelection(by: 1)
    case .moveToPrevious: store.moveSelection(by: -1)
    case .moveToFirst: store.selectEdge(last: false)
    case .moveToLast: store.selectEdge(last: true)
    case .pinOrUnpin: appState.togglePin()
    case .deleteCurrentItem: appState.deleteSelection()
    case .clearHistory, .clearHistoryAll: store.showClearConfirmation = true
    case .clearSearch: searchQuery = ""
    case .close: appState.popup.close()
    case .selectCurrentItem: appState.select()
    case .openPreferences: appState.openPreferences()
    default: return .ignored
    }
    return .handled
  }

}
