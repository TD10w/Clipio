# UI Motion + File Drag-Out Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add open/close pop animation to the shelf window, a scale-pop on card selection, and file-URL drag-out to Finder — all as lightweight, additive changes with no regressions.

**Architecture:** Feature 1 lives entirely in `FloatingPanel` (AppKit layer animation + NSAnimationContext). Feature 2 is a pure SwiftUI `keyframeAnimator` in `CardItemView`. Feature 3 adds one branch to `dragProvider()` and one to `dragPreview()` in `CardItemView`.

**Tech Stack:** AppKit (`NSAnimationContext`, `CABasicAnimation`), SwiftUI (`keyframeAnimator`, `onChange`), `NSItemProvider`, `NSWorkspace`.

---

## Files touched

| File | What changes |
|---|---|
| `Maccy/FloatingPanel.swift` | Add animation constants + `isAnimatingClose` flag; rewrite `open()` open sequence; override `close()` to animate then defer `super.close()` via `commitClose()` helper |
| `Maccy/Views/CardItemView.swift` | Add `selectionPopPhase` state + `keyframeAnimator` + `onChange` for Feature 2; add file-URL branch in `dragProvider()` and `dragPreview()` for Feature 3 |

---

## Task 1 — Open/Close Pop Animation (`FloatingPanel.swift`)

**Files:**
- Modify: `Maccy/FloatingPanel.swift`

### Context

`FloatingPanel` currently sets `alphaValue = 1` in `open()` and calls `super.close()` directly in `close()`. We will:
1. Fade + scale the window in on open (0.96 → 1.0, alpha 0 → 1).
2. Reverse on close (1.0 → 0.96, alpha 1 → 0), defer the actual `super.close()` to the animation completion handler.
3. Keep `prewarm()` / `finishPrewarming()` paths untouched — they never call `open()` or `close()`.

Key constraints:
- `super.close()` cannot be called from inside a closure in Swift (compiler error). Use a private `commitClose()` helper.
- Guard `close()` against re-entry during the close animation with `isAnimatingClose`.
- `open()` cancels any in-progress close animation before starting.

- [ ] **Step 1: Add animation constants, `isAnimatingClose` flag, and `commitClose()` helper**

Open `Maccy/FloatingPanel.swift`. After the existing `private var isPrewarming = false` line (line 11), add:

```swift
  private var isAnimatingClose = false

  // Animation tunables — one-line changes to dial in the feel.
  private static let openDuration: TimeInterval = 0.14
  private static let closeDuration: TimeInterval = 0.10
  private static let openFromScale: CGFloat = 0.96
```

Then, just before the `init(` declaration (around line 44), add the private helper that lets a closure call super:

```swift
  private func commitClose() {
    super.close()
  }
```

- [ ] **Step 2: Rewrite `open()` to animate in**

Replace the entire `open(height:at:)` method (currently lines 116–148) with:

```swift
  func open(height: CGFloat, at popupPosition: PopupPosition = Defaults[.popupPosition]) {
    // Cancel any in-progress close animation so we start clean.
    isAnimatingClose = false
    contentView?.layer?.removeAllAnimations()

    isPrewarming = false
    ignoresMouseEvents = false
    let desired = Defaults[.appearanceMode].nsAppearance
    if appearance?.name != desired?.name {
      appearance = desired
    }
    let size = Defaults[.windowSize]
    let targetHeight = height > 0 ? min(height, size.height) : size.height
    setContentSize(NSSize(width: min(frame.width, size.width), height: targetHeight))
    if let screen = NSScreen.main {
      let visible = screen.visibleFrame
      let originX = visible.minX + (visible.width - frame.width) / 2
      let originY = visible.maxY - frame.height
      setFrameOrigin(NSPoint(x: originX, y: originY))
    } else {
      setFrameOrigin(popupPosition.origin(size: frame.size, statusBarButton: statusBarButton))
    }

    // Start invisible + scaled down, then pop into view.
    alphaValue = 0
    contentView?.wantsLayer = true
    // Set model at final (identity) so animation removal snaps to full-size correctly.
    contentView?.layer?.transform = CATransform3DIdentity

    orderFrontRegardless()
    makeKey()
    isPresented = true

    // Fade alpha via NSAnimationContext (implicit NSWindow animation).
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = Self.openDuration
      ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
      animator().alphaValue = 1
    }

    // Scale via explicit CABasicAnimation; fromValue starts at 0.96, model already at 1.0.
    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
    scaleAnim.fromValue = Self.openFromScale
    scaleAnim.duration = Self.openDuration
    scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
    contentView?.layer?.add(scaleAnim, forKey: "popOpen")

    if popupPosition == .statusItem {
      DispatchQueue.main.async {
        self.statusBarButton?.isHighlighted = true
      }
    }
  }
```

- [ ] **Step 3: Override `close()` to animate out and defer teardown**

Replace the entire `close()` override (currently lines 171–177) with:

```swift
  override func close() {
    guard !isAnimatingClose else { return }
    isAnimatingClose = true

    AppState.shared.appDelegate?.hidePreviewNow()
    isPresented = false
    statusBarButton?.isHighlighted = false

    // Set model at final (scaled-down) so removal snaps correctly; fromValue = 1.0.
    contentView?.layer?.transform = CATransform3DMakeScale(Self.openFromScale, Self.openFromScale, 1)
    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
    scaleAnim.fromValue = 1.0
    scaleAnim.duration = Self.closeDuration
    scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
    contentView?.layer?.add(scaleAnim, forKey: "popClose")

    NSAnimationContext.runAnimationGroup({ ctx in
      ctx.duration = Self.closeDuration
      ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
      animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      guard let self else { return }
      self.isAnimatingClose = false
      // Reset layer to identity so the next open starts clean.
      self.contentView?.layer?.removeAllAnimations()
      self.contentView?.layer?.transform = CATransform3DIdentity
      self.alphaValue = 1
      self.commitClose()   // calls super.close() — orders out the window
      self.onClose()
    })
  }
```

- [ ] **Step 4: Compile-check**

```bash
cd "/Users/dx/Documents/Claude/Claude Code/Clipio"
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED` with no `error:` lines. Fix any issues before continuing.

- [ ] **Step 5: Manually verify in the installed Release build**

Build and install the Release build via the usual `Install Clipio.command` / double-click installer, then:
- Open with the hotkey → shelf pops in (fades + scales up, ~0.14s). Should feel snappy, not slow.
- Close with the hotkey → shelf fades + scales down.
- Click outside the shelf → same close animation.
- Rapid open/close → no crashes, no stuck-on-screen window.
- Open the app at launch (prewarm path): shelf should still appear instantly on first hotkey with no jank.

If the pop feels too slow or too dramatic, change `openDuration`, `closeDuration`, or `openFromScale` at the top of `FloatingPanel` — they're in one place for exactly this reason.

- [ ] **Step 6: Commit**

```bash
git add Maccy/FloatingPanel.swift
git commit -m "feat: add open/close pop animation to the shelf window

Shelf fades + scales from 0.96→1.0 on open and reverses on close.
Duration/scale are named constants for easy tuning. Prewarm path
and resignKey close path are unaffected."
```

---

## Task 2 — Card Selection Scale Pop (`CardItemView.swift`)

**Files:**
- Modify: `Maccy/Views/CardItemView.swift`

### Context

When a card becomes selected (click or arrow key), it should briefly bump to ~106% then spring back. We use `keyframeAnimator` (available macOS 14+, which SwiftData already requires) triggered by a toggle on `item.isSelected` change.

The `scaleEffect` in the keyframe animator wraps the entire card view (after all overlays). It uses `.center` anchor so the bump is symmetric. The bump is 7ms instant scale-up followed by a bouncy spring back — giving the "pop" feel without any timed delay code.

- [ ] **Step 1: Add `selectionPopPhase` state variable**

In `CardItemView.swift`, after the existing `@State private var isHovered = false` line (currently line 11), add:

```swift
  @State private var selectionPopPhase = false
```

- [ ] **Step 2: Add keyframe animator and onChange to the view modifier chain**

In the `body` computed property, find the existing `.animation(.easeOut(duration: 0.16), value: isHovered)` line (currently line 85). After that line and before `.accessibilityElement(children: .ignore)`, insert:

```swift
    .keyframeAnimator(initialValue: CGFloat(1.0), trigger: selectionPopPhase) { content, scale in
      content.scaleEffect(scale, anchor: .center)
    } keyframes: { _ in
      LinearKeyframe(1.06, duration: 0.07)
      SpringKeyframe(1.0, duration: 0.22, spring: .bouncy(duration: 0.22, extraBounce: 0.05))
    }
    .onChange(of: item.isSelected) { _, isSelected in
      guard isSelected else { return }
      selectionPopPhase.toggle()
    }
```

- [ ] **Step 3: Compile-check**

```bash
cd "/Users/dx/Documents/Claude/Claude Code/Clipio"
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manually verify in the installed Release build**

- Click a card → it pops to ~106% and springs back to normal. Should feel crisp, not wobbly.
- Arrow-key through cards → each card pops as it becomes selected.
- Cards should not clip against neighbors (the 6% bump fits within `cardSpacing`).
- Selection ring (blue stroke) remains visible alongside the pop.
- Repeated selection of the same card (navigate away and back) → pop fires again each time.

If the bounce feels too strong, reduce `extraBounce` toward 0. If not bouncy enough, increase it toward 0.15.

- [ ] **Step 5: Commit**

```bash
git add Maccy/Views/CardItemView.swift
git commit -m "feat: add scale-pop animation on card selection

Selected card briefly bumps to 106% and springs back using
keyframeAnimator. Pure SwiftUI transform, no layout impact."
```

---

## Task 3 — Drag Files Out (`CardItemView.swift`)

**Files:**
- Modify: `Maccy/Views/CardItemView.swift`

### Context

`HistoryItem.fileURLs: [URL]` already exists and is populated for items copied from Finder. We add a branch at the **top** of `dragProvider()` — before the image branch — so file items are dragged as actual files (not as raw image data, even if the item also has image content). We also update `dragPreview()` to show the filename and Finder icon.

`NSItemProvider(contentsOf: URL)` is the simplest API for registering a file drag that Finder accepts; it returns `nil` if the file can't be read, so we fall through to the text path gracefully.

- [ ] **Step 1: Add file-URL branch to `dragProvider()`**

In `CardItemView.swift`, find the `dragProvider()` method. Replace the entire method with:

```swift
  private func dragProvider() -> NSItemProvider {
    // Keep the panel open while the drag is in flight, otherwise resignKey closes it
    // and cancels the drag. FloatingPanel clears this on the next mouse-up.
    AppState.shared.appDelegate?.panel.isDragging = true

    // File item: hand the real file URL to the OS so Finder / other apps accept a file drop.
    if let url = item.item.fileURLs.first,
       let provider = NSItemProvider(contentsOf: url) {
      return provider
    }

    let provider = NSItemProvider()

    // Image item: hand over normalized PNG data so other apps accept the drop.
    if item.hasImage,
       let data = item.item.imageData,
       let rep = NSBitmapImageRep(data: data),
       let png = rep.representation(using: .png, properties: [:]) {
      provider.registerDataRepresentation(
        forTypeIdentifier: UTType.png.identifier,
        visibility: .all
      ) { completion in
        completion(png, nil)
        return nil
      }
      return provider
    }

    // Text item.
    let text = item.text
    provider.registerDataRepresentation(
      forTypeIdentifier: UTType.utf8PlainText.identifier,
      visibility: .all
    ) { completion in
      completion(Data(text.utf8), nil)
      return nil
    }
    return provider
  }
```

- [ ] **Step 2: Add file preview to `dragPreview()`**

Replace the entire `dragPreview()` method with:

```swift
  @ViewBuilder
  private func dragPreview() -> some View {
    if let url = item.item.fileURLs.first {
      HStack(spacing: 8) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
          .resizable()
          .frame(width: 28, height: 28)
        Text(url.lastPathComponent)
          .font(.system(size: 12))
          .lineLimit(2)
      }
      .padding(10)
      .frame(maxWidth: 220, alignment: .leading)
      .background(.regularMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    } else if let image = item.thumbnailImage {
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: 200, maxHeight: 150)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } else {
      Text(item.text)
        .font(.system(size: 12))
        .lineLimit(4)
        .padding(10)
        .frame(maxWidth: 200, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
```

- [ ] **Step 3: Compile-check**

```bash
cd "/Users/dx/Documents/Claude/Claude Code/Clipio"
xcodebuild -project "Clipio.xcodeproj" -scheme "Maccy" -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Manually verify in the installed Release build**

Setup: Copy a file from Finder to the clipboard (⌘C on a file in Finder). Open Clipio.
- The file item appears as a card (shows the file path as text).
- Drag the file card into a Finder window → the real file should land there (Finder shows it in the destination folder).
- Drag the file card into another app that accepts files (e.g., a text editor that opens dropped files) → app should open/receive the file.
- Drag a text card (not a file) → still drags as text. No regression.
- Drag an image card → still drags as PNG. No regression.
- Drag a card whose file has been deleted → falls through to text path (no crash).

Note: if the original file was moved or deleted, the drag won't produce it. This is expected behavior consistent with macOS file clipboard semantics.

- [ ] **Step 5: Commit**

```bash
git add Maccy/Views/CardItemView.swift
git commit -m "feat: drag file-type cards out to Finder as real files

Add file-URL branch to dragProvider() before the image branch.
Uses NSItemProvider(contentsOf:) which Finder accepts as a file drop.
Falls through to text if the file is missing. Updates dragPreview()
to show the file icon + name for file-type items."
```
