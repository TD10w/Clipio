import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }

      // Only a faint specular highlight on the tray — no ambient colour wash — so the
      // native glass refracts the desktop instead of looking like a frosted slab.
      LinearGradient(
        colors: [
          Color.white.opacity(0.04),
          Color.clear,
          FloatingGlassStyle.spectralTint.opacity(0.012)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
        .allowsHitTesting(false)

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        shelfContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
      }
    }
    // A single restrained perimeter reads the tray as one continuous lens of glass.
    .overlay(
      RoundedRectangle(cornerRadius: FloatingGlassStyle.trayRadius, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              Color.white.opacity(0.30),
              FloatingGlassStyle.rimTint.opacity(0.22),
              FloatingGlassStyle.spectralTint.opacity(0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
        .allowsHitTesting(false)
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

  // The header + card row. On macOS 26 they share one GlassEffectContainer so the
  // search field, controls, and cards sample a single coherent glass field.
  @ViewBuilder
  private var shelfContent: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: FloatingGlassStyle.cardSpacing) {
        shelfStack
      }
    } else {
      shelfStack
    }
  }

  private var shelfStack: some View {
    VStack(spacing: 0) {
      HeaderView(
        controller: appState.preview,
        searchFocused: $searchFocused
      )

      HistoryListView(
        searchQuery: $appState.history.searchQuery,
        searchFocused: $searchFocused
      )
    }
    .onAppear {
      searchFocused = true
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
