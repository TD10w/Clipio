import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background

  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var searchFocused: Bool

  var body: some View {
    ZStack {
      trayGlass

      // In light mode the "clear" glass has no visual body — the desktop shows straight
      // through, leaving cards floating on nothing. A white scrim gives the shelf mass.
      if colorScheme == .light {
        RoundedRectangle(cornerRadius: FloatingGlassStyle.trayRadius, style: .continuous)
          .fill(Color.white.opacity(0.55))
      }

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
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
    // A single restrained perimeter reads the tray as one continuous lens of glass.
    // Color.primary adapts: white in dark mode (gloss), near-black in light mode (visible edge).
    .overlay(
      RoundedRectangle(cornerRadius: FloatingGlassStyle.trayRadius, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              Color.primary.opacity(0.22),
              FloatingGlassStyle.rimTint.opacity(0.26),
              FloatingGlassStyle.spectralTint.opacity(0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
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

  // The tray itself is one native Liquid Glass lozenge that refracts the desktop.
  // SwiftUI glass keeps the tray in the native Liquid Glass rendering system.
  @ViewBuilder
  private var trayGlass: some View {
    let shape = RoundedRectangle(cornerRadius: FloatingGlassStyle.trayRadius, style: .continuous)
    if #available(macOS 26.0, *) {
      Color.clear
        .glassEffect(.clear, in: shape)
    } else {
      VisualEffectView()
        .clipShape(shape)
    }
  }

  // The header + card row. Cards and controls are solid material now (not glass),
  // so there is no GlassEffectContainer — that keeps text/badges crisp and the
  // shelf lightweight, with the tray as the single glass surface.
  private var shelfContent: some View {
    shelfStack
  }

  private var shelfStack: some View {
    VStack(spacing: 0) {
      HeaderView(
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
