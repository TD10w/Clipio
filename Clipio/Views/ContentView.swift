import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      trayGlass

      KeyHandlingView(searchQuery: $appState.activeSearchQuery, searchFocused: $searchFocused) {
        shelfContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      // Header + cards appear only once the glass has unfolded.
      .opacity(appState.shelfExpanded ? 1 : 0)
      .animation(
        .easeOut(duration: FloatingGlassStyle.contentFadeDuration)
          .delay(appState.shelfExpanded ? FloatingGlassStyle.contentFadeDelay : 0),
        value: appState.shelfExpanded
      )
    }
    // A semantic edge keeps the material legible across system appearances.
    .overlay(
      RoundedRectangle(cornerRadius: FloatingGlassStyle.trayRadius, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        .allowsHitTesting(false)
    )
    // The glass body unfolds from a small chip at the top-center into the full shelf.
    // scaleEffect is a GPU transform (no relayout) and settles to identity, so it can't
    // shift AppKit hit-testing the way the removed window-layer scale did.
    .scaleEffect(
      x: appState.shelfExpanded ? 1 : FloatingGlassStyle.seedScaleX,
      y: appState.shelfExpanded ? 1 : FloatingGlassStyle.seedScaleY,
      anchor: .top
    )
    .animation(
      .spring(
        response: FloatingGlassStyle.unfoldResponse,
        dampingFraction: FloatingGlassStyle.unfoldDamping
      ),
      value: appState.shelfExpanded
    )
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
  }

  private var trayGlass: some View {
    Color.clear.modifier(ShelfGlassSurface(radius: FloatingGlassStyle.trayRadius))
  }

  // Native frosted cards keep text and badges clear within the glass shelf.
  private var shelfContent: some View {
    shelfStack
  }

  private var shelfStack: some View {
    VStack(spacing: 0) {
      HeaderView(
        searchFocused: $searchFocused
      )

      if appState.shelfMode == .collection {
        CollectionShelfView(store: appState.collection)
      } else {
        HistoryListView(
          searchQuery: $appState.history.searchQuery,
          searchFocused: $searchFocused
        )
      }
    }
    .onAppear {
      searchFocused = true
    }
    .onChange(of: appState.shelfMode) {
      searchFocused = false
      DispatchQueue.main.async { searchFocused = true }
    }
    .onMouseMove {
      appState.navigator.isKeyboardNavigating = false
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
