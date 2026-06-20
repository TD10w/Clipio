# Card Shelf UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Maccy's vertical clipboard list with a wide, fixed-height horizontal card shelf that drops from the menu bar, with drag-and-drop support for pasting items into any app.

**Architecture:** Keep all of Maccy's core logic (clipboard polling, storage, search, keyboard shortcuts) completely untouched. Only the presentation layer changes: `ContentView` gets simplified (SlideoutView and FooterView removed), `HistoryListView` becomes a horizontal `ScrollView`, and a new `CardItemView` replaces `ListItemView` as the visual unit. A `isDragging` flag on `FloatingPanel` prevents the window from closing mid-drag.

**Tech Stack:** SwiftUI, AppKit, NSItemProvider (for drag-and-drop), existing Maccy observables (`AppState`, `HistoryItemDecorator`, `Popup`)

---

## File Map

| File | Action | What changes |
|---|---|---|
| `Maccy/Extensions/Defaults.Keys+Names.swift` | Modify line 58 | Default window size → wide/short shelf |
| `Maccy/FloatingPanel.swift` | Modify | Add `isDragging` flag; check it in `resignKey()` |
| `Maccy/Views/ContentView.swift` | Modify | Remove `SlideoutView` wrapper and `FooterView` |
| `Maccy/Views/HistoryListView.swift` | Rewrite | Vertical scroll → horizontal card scroll |
| `Maccy/Views/CardItemView.swift` | **Create** | New fixed-size card with image/text/color variants + drag |

Do **not** touch: `Clipboard.swift`, `History.swift`, `Storage.swift`, `AppDelegate.swift`, `Popup.swift`, `HeaderView.swift`, `HistoryItemDecorator.swift`, or any model/search files.

---

## Task 1: Set default window size to shelf proportions

**Files:**
- Modify: `Maccy/Extensions/Defaults.Keys+Names.swift:58`

- [ ] **Step 1: Change the default windowSize**

Find line 58 in `Defaults.Keys+Names.swift`:
```swift
static let windowSize = Key<NSSize>("windowSize", default: NSSize(width: 450, height: 800))
```
Replace with:
```swift
static let windowSize = Key<NSSize>("windowSize", default: NSSize(width: 820, height: 200))
```

- [ ] **Step 2: Reset stored window size so the change takes effect**

The app persists window size to UserDefaults. On first run after this change, the old size will still be stored. Add a reset in `AppDelegate.applicationWillFinishLaunching` right before the panel is created (around line 95 in `AppDelegate.swift`). Find this block:

```swift
panel = FloatingPanel(
  contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
```

Add one line above it:
```swift
Defaults.reset(.windowSize)
panel = FloatingPanel(
  contentRect: NSRect(origin: .zero, size: Defaults[.windowSize]),
```

> **Note:** Remove the `Defaults.reset(.windowSize)` line after the first successful build. It's only needed to clear the cached size from any previous Maccy install. Once you've built and run once, delete that line and rebuild.

- [ ] **Step 3: Build and run**

In Xcode: `Cmd+R`. Press `Shift+Cmd+C`. You should see the popup appear — it will be at the old size for now (the layout changes come next), but it shouldn't crash.

- [ ] **Step 4: Commit**

```bash
cd /Users/dubulu/Documents/AgentOS/Project/Maccy
git add Maccy/Extensions/Defaults.Keys+Names.swift Maccy/AppDelegate.swift
git commit -m "feat: set default window size to wide shelf (820x200)"
```

---

## Task 2: Prevent window from closing during drag

**Files:**
- Modify: `Maccy/FloatingPanel.swift`

This must be done before adding drag support in Task 5. When the user starts dragging a card to another app, macOS briefly shifts focus, which normally triggers `resignKey()` → `close()`, killing the drag mid-flight.

- [ ] **Step 1: Add `isDragging` property**

In `FloatingPanel.swift`, after line 8 (`var statusBarButton: NSStatusBarButton?`), add:

```swift
var isDragging: Bool = false
```

- [ ] **Step 2: Guard `resignKey()` with the flag**

Find `resignKey()` (around line 193):
```swift
override func resignKey() {
    super.resignKey()
    if NSApp.alertWindow == nil {
        close()
    }
}
```

Replace with:
```swift
override func resignKey() {
    super.resignKey()
    if NSApp.alertWindow == nil && !isDragging {
        close()
    }
}
```

- [ ] **Step 3: Build and confirm no errors**

`Cmd+B` in Xcode. Should compile cleanly.

- [ ] **Step 4: Commit**

```bash
git add Maccy/FloatingPanel.swift
git commit -m "feat: prevent window close during drag-and-drop"
```

---

## Task 3: Create CardItemView

**Files:**
- Create: `Maccy/Views/CardItemView.swift`

This is the new visual unit. Each card is 130×140pt, dark background, rounded corners. Content area shows: large image thumbnail, or a color swatch, or text preview. Footer strip shows: source app icon + relative time.

- [ ] **Step 1: Create the file**

Create `Maccy/Views/CardItemView.swift` with this content:

```swift
import SwiftUI

struct CardItemView: View {
  let item: HistoryItemDecorator
  let onSelect: () -> Void

  @State private var isHovered = false

  private static let cardWidth: CGFloat = 130
  private static let cardHeight: CGFloat = 140
  private static let footerHeight: CGFloat = 28

  private var timeString: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: item.item.lastCopiedAt, relativeTo: Date())
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      cardContent
      cardFooter
    }
    .frame(width: Self.cardWidth, height: Self.cardHeight)
    .background(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 0.5)
    )
    .onHover { isHovered = $0 }
    .onTapGesture { onSelect() }
    .onDrag {
      dragProvider()
    } preview: {
      dragPreview()
    }
  }

  @ViewBuilder
  private var cardContent: some View {
    if let image = item.thumbnailImage {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: Self.cardWidth, height: Self.cardHeight - Self.footerHeight)
        .clipped()
        .frame(maxHeight: .infinity, alignment: .top)
    } else if let colorImage = ColorImage.from(item.title) {
      colorCard(colorImage: colorImage)
    } else {
      textCard
    }
  }

  @ViewBuilder
  private func colorCard(colorImage: NSImage) -> some View {
    VStack(spacing: 0) {
      Image(nsImage: colorImage)
        .resizable()
        .frame(width: Self.cardWidth, height: Self.cardHeight - Self.footerHeight - 24)
      Text(item.title)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var textCard: some View {
    Text(item.text)
      .font(.system(size: 11))
      .foregroundStyle(.white.opacity(0.85))
      .lineLimit(6)
      .multilineTextAlignment(.leading)
      .padding(.horizontal, 8)
      .padding(.top, 8)
      .padding(.bottom, Self.footerHeight + 4)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var cardFooter: some View {
    HStack(spacing: 4) {
      AppImageView(appImage: item.applicationImage, size: NSSize(width: 14, height: 14))
      Text(timeString)
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.5))
        .lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 7)
    .frame(height: Self.footerHeight)
    .background(.black.opacity(0.35))
  }

  private func dragProvider() -> NSItemProvider {
    // Set isDragging on the panel to prevent it closing mid-drag
    if let panel = NSApp.windows.compactMap({ $0 as? FloatingPanel<ContentView> }).first {
      panel.isDragging = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        panel.isDragging = false
      }
    }

    if let image = item.thumbnailImage {
      return NSItemProvider(object: image)
    }
    return NSItemProvider(object: item.text as NSString)
  }

  @ViewBuilder
  private func dragPreview() -> some View {
    if let image = item.thumbnailImage {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: 200, maxHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } else {
      Text(item.text)
        .font(.system(size: 12))
        .padding(8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 200)
    }
  }
}
```

- [ ] **Step 2: Add the file to the Xcode project**

In Xcode, right-click the `Views` group in the file navigator → **Add Files to "Maccy"** → select `CardItemView.swift` → make sure "Add to target: Maccy" is checked → Add.

> If you created the file via terminal/editor and Xcode doesn't see it, use this method to register it.

- [ ] **Step 3: Build and check for errors**

`Cmd+B`. Fix any compile errors — most likely will be `FloatingPanel<ContentView>` type casting in `dragProvider()`. If needed, simplify to:

```swift
private func dragProvider() -> NSItemProvider {
    if let image = item.thumbnailImage {
        return NSItemProvider(object: image)
    }
    return NSItemProvider(object: item.text as NSString)
}
```

(The `isDragging` part can be wired up later if the simpler version works.)

- [ ] **Step 4: Commit**

```bash
git add Maccy/Views/CardItemView.swift
git commit -m "feat: add CardItemView for horizontal card shelf"
```

---

## Task 4: Rewrite HistoryListView as horizontal shelf

**Files:**
- Modify: `Maccy/Views/HistoryListView.swift`

The entire body is replaced. Pins and paste stack are simplified — pinned items appear first in the horizontal scroll, paste stack is skipped for now.

- [ ] **Step 1: Replace the entire file content**

Open `Maccy/Views/HistoryListView.swift` and replace everything from `var body: some View {` to the final closing `}` with:

```swift
  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 8) {
        ForEach(pinnedItems) { item in
          CardItemView(item: item) {
            Task { appState.history.select(item) }
          }
        }

        ForEach(unpinnedItems) { item in
          CardItemView(item: item) {
            Task { appState.history.select(item) }
          }
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      appState.navigator.select(item: appState.history.unpinnedItems.first ?? appState.history.pinnedItems.first)
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active {
        searchFocused = true
        appState.navigator.select(item: appState.history.unpinnedItems.first ?? appState.history.pinnedItems.first)
      }
    }
  }
```

Also remove these private computed properties that are no longer used (they'll cause compiler warnings):
- `showPinsSeparator`
- `pinsVisible`  
- `pasteStackVisible`
- `topPadding`
- `bottomPadding`
- `topSeparator()`
- `bottomSeparator()`
- `separator()`

Keep: `pinnedItems`, `unpinnedItems`, and the `@Default`/`@Environment`/`@FocusState` declarations at the top.

Also remove the unused `@Default(.pinTo)` and `@Default(.showFooter)` if they cause warnings (they were only used in the removed logic).

- [ ] **Step 2: Build and check**

`Cmd+B`. The most likely error is a missing import or unused variable warning-as-error.

- [ ] **Step 3: Run and test**

`Cmd+R`. Press `Shift+Cmd+C`. You should now see a horizontal row of cards. Scroll left/right with the trackpad or mouse wheel.

- [ ] **Step 4: Commit**

```bash
git add Maccy/Views/HistoryListView.swift
git commit -m "feat: replace vertical list with horizontal card scroll"
```

---

## Task 5: Simplify ContentView (remove slideout + footer)

**Files:**
- Modify: `Maccy/Views/ContentView.swift`

The preview slideout panel is no longer needed (drag-to-paste replaces it). The footer (Clear/Quit) is removed for cleaner shelf look.

- [ ] **Step 1: Replace the body in ContentView.swift**

Find the `body` in `ContentView.swift` and replace it with:

```swift
  var body: some View {
    ZStack {
      if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
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
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
      }
    }
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
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
```

- [ ] **Step 2: Build and run**

`Cmd+R`. The shelf should now appear without a slideout panel or footer. Press `Shift+Cmd+C`, verify the search bar and cards show up cleanly.

- [ ] **Step 3: Commit**

```bash
git add Maccy/Views/ContentView.swift
git commit -m "feat: simplify ContentView, remove slideout panel and footer for shelf layout"
```

---

## Task 6: Test drag-and-drop end-to-end

No code changes — this is a manual QA task.

- [ ] **Test 1: Text drag**
  1. Copy some text (e.g. from Safari)
  2. Open Clip Barns (`Shift+Cmd+C`)
  3. Drag a text card to a text field in any app (Notes, Messages, etc.)
  4. Expected: text appears in the field

- [ ] **Test 2: Image drag**
  1. Copy an image (right-click in browser → Copy Image)
  2. Open Clip Barns
  3. Drag the image card to a supported app (Slack message field, Mail compose, Figma)
  4. Expected: image appears

- [ ] **Test 3: Window stays open during drag**
  1. Start dragging a card
  2. Hover over a text field in another app
  3. Expected: Clip Barns window stays visible while dragging; closes after you drop

- [ ] **If drag causes window to immediately close:**
  The `isDragging` flag from Task 2 needs to be properly wired. Go back to `CardItemView.dragProvider()` and ensure `panel.isDragging = true` is being set. Also extend the asyncAfter delay to 5 seconds for testing.

- [ ] **Step: Commit if any fixes were made**

```bash
git add -p
git commit -m "fix: wire isDragging flag to prevent panel close on drag"
```

---

## Task 7: Rename app to Clip Barns (manual Xcode step)

This must be done in Xcode's GUI — not in code files.

- [ ] **Step 1: Change Display Name**
  - In Xcode, click the project root (blue icon, top of file navigator)
  - Select target **Maccy** → **General** tab
  - Change **Display Name** from `Maccy` to `Clip Barns`

- [ ] **Step 2: Change Bundle Identifier**
  - On the same General tab, change **Bundle Identifier** from `org.p0deje.Maccy` to `com.clipbarns.app`

- [ ] **Step 3: Build and verify**
  - `Cmd+R`
  - The menu bar icon should now show "Clip Barns" in About (⌘ → About Maccy → will show old name until you also update Info.plist display name)
  - The app in `/Applications` or the build output will be named `Clip Barns.app`

- [ ] **Step 4: Commit**

```bash
git add Maccy.xcodeproj/project.pbxproj
git commit -m "chore: rename app to Clip Barns"
```

---

## Known Risks & Notes

**Drag from non-activating panel** — `FloatingPanel` uses `.nonactivatingPanel` style, which doesn't steal focus. This is good for drag sources (the target app's text field stays focused). However, if the window closes mid-drag (from `resignKey()`), the drag will be cancelled. Task 2's `isDragging` flag handles this, but the 2-second timeout is a rough heuristic — if drag takes longer, extend it.

**`ColorImage.from(_:)`** — This utility already exists in Maccy and detects hex color strings (`#FF0000`, `rgb(...)`, etc.). Used in `CardItemView` to show color swatches automatically.

**Window height sizing** — With the old vertical layout removed, `Popup.resize(height:)` no longer gets called, so the window opens at whatever `Defaults[.windowSize].height` is set to (200px after Task 1). If the window appears too small or too tall, adjust the `height: 200` value in `Defaults.Keys+Names.swift`.

**Search behavior** — Search still works via `HeaderView` + `History.searchQuery`. The `HistoryListView` reads `unpinnedItems` and `pinnedItems` which are already filtered by the search. No changes needed.

**Keyboard navigation** — Arrow key navigation (up/down) won't make sense in horizontal layout. Left/right arrows may or may not work depending on `KeyHandlingView`. This is a known degradation — keyboard nav is deprioritized for the shelf layout.
