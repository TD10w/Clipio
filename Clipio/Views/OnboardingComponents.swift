import AppKit
import KeyboardShortcuts
import SwiftUI

/// Building blocks for the Getting Started guide. They reuse the shelf's glass language
/// (behind-window blur, spectral rim, frosted cards, material key caps) so the guide
/// looks like part of Clipio rather than a generic setup window.
enum OnboardingMetrics {
  static let windowSize = CGSize(width: 560, height: 600)
  static let windowRadius: CGFloat = 26
  /// The guide holds paragraphs of text, so it sits at the frosted end of the
  /// shelf's transparency range regardless of the user's shelf setting.
  static let frostPosition = 0.75
}

struct OnboardingGlassBackground: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: OnboardingMetrics.windowRadius, style: .continuous)
    let dark = colorScheme == .dark
    ZStack {
      if reduceTransparency {
        shape.fill(Color(nsColor: .windowBackgroundColor))
      } else {
        VisualEffectView().clipShape(shape)
        shape.fill((dark ? Color.black : Color.white)
          .opacity(FloatingGlassStyle.tintOpacity(OnboardingMetrics.frostPosition, dark: dark)))
      }
    }
    .overlay(ShelfGlassRim(radius: OnboardingMetrics.windowRadius))
  }
}

/// A frosted panel with the same surface and rim as a shelf card.
struct OnboardingCard: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .modifier(FloatingGlassCardBackground(isHovered: false))
  }
}

extension View {
  func onboardingCard() -> some View { modifier(OnboardingCard()) }
}

/// A shortcut rendered like the shelf's round material header controls.
struct OnboardingKeyCap: View {
  let text: String
  var large = false

  var body: some View {
    Text(verbatim: text)
      .font(.system(size: large ? 22 : 15, weight: .medium, design: .rounded))
      .tracking(large ? 1.5 : 0.5)
      .padding(.horizontal, large ? 16 : 10)
      .padding(.vertical, large ? 8 : 4)
      .background(.regularMaterial, in: Capsule())
      .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8))
      .accessibilityIdentifier("onboarding-shortcut")
  }
}

struct OnboardingBadge: View {
  let key: LocalizedStringKey

  var body: some View {
    Text(key)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.accentColor)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(Color.accentColor.opacity(0.12), in: Capsule())
  }
}

/// One step of a practice checklist. The accessory (usually a button) only shows
/// while the row is the current step.
struct OnboardingTaskRow<Accessory: View>: View {
  let done: Bool
  let current: Bool
  let title: String
  var detail: String?
  @ViewBuilder var accessory: () -> Accessory

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        if done {
          Circle().fill(Color.green)
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
        } else {
          Circle().strokeBorder(
            current ? Color.accentColor : Color.primary.opacity(0.25),
            lineWidth: 1.5
          )
        }
      }
      .frame(width: 20, height: 20)
      .padding(.top, 1)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: done)

      VStack(alignment: .leading, spacing: 3) {
        Text(verbatim: title)
          .font(.system(size: 13.5, weight: .medium))
          .foregroundStyle(done ? .secondary : .primary)
        if let detail {
          Text(verbatim: detail)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if current && !done {
          accessory().padding(.top, 5)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 7)
    .accessibilityElement(children: .contain)
    .accessibilityValue(Text(done ? "onboarding_done_value" : ""))
  }
}

extension OnboardingTaskRow where Accessory == EmptyView {
  init(done: Bool, current: Bool, title: String, detail: String? = nil) {
    self.init(done: done, current: current, title: title, detail: detail) { EmptyView() }
  }
}

/// Practice box the user pastes into. Clipio has no Edit menu, so the field handles
/// ⌘V itself; this also catches the ⌘V that automatic paste posts.
struct OnboardingPasteField: View {
  @Binding var text: String
  let identifier: String

  var body: some View {
    HStack(spacing: 10) {
      PasteTargetRepresentable(
        text: $text,
        placeholder: NSLocalizedString("onboarding_paste_placeholder", comment: ""),
        identifier: identifier
      )
      .frame(height: 22)
      if !text.isEmpty {
        Label("onboarding_pasted", systemImage: "checkmark.circle.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.green)
          .transition(.opacity)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(text.isEmpty ? Color.primary.opacity(0.12) : Color.green.opacity(0.6), lineWidth: 1)
    )
    .animation(.easeOut(duration: 0.2), value: text.isEmpty)
  }
}

private struct PasteTargetRepresentable: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String
  let identifier: String

  func makeNSView(context: Context) -> PasteTargetTextField {
    let field = PasteTargetTextField()
    field.placeholderString = placeholder
    field.delegate = context.coordinator
    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 14)
    field.lineBreakMode = .byTruncatingTail
    field.cell?.usesSingleLineMode = true
    field.setAccessibilityIdentifier(identifier)
    DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
    return field
  }

  func updateNSView(_ field: PasteTargetTextField, context: Context) {
    if field.stringValue != text { field.stringValue = text }
  }

  func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    let text: Binding<String>
    init(text: Binding<String>) { self.text = text }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTextField else { return }
      text.wrappedValue = field.stringValue
    }
  }
}

final class PasteTargetTextField: NSTextField {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
    let isV = event.charactersIgnoringModifiers?.lowercased() == "v" || event.keyCode == 9
    guard modifiers == .command, isV, window?.isKeyWindow == true else {
      return super.performKeyEquivalent(with: event)
    }
    if currentEditor() == nil { window?.makeFirstResponder(self) }
    currentEditor()?.paste(nil)
    return true
  }
}

/// The library's recorder, focused as soon as it appears so "Change…" starts recording.
struct OnboardingShortcutRecorder: NSViewRepresentable {
  let onChange: (KeyboardShortcuts.Shortcut?) -> Void

  func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
    let recorder = KeyboardShortcuts.RecorderCocoa(for: .popup, onChange: onChange)
    recorder.setAccessibilityIdentifier("onboarding-shortcut-recorder")
    DispatchQueue.main.async { recorder.window?.makeFirstResponder(recorder) }
    return recorder
  }

  func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context: Context) {}
}

/// A sample picture the user drags to the Drop Zone at the top of the screen. It
/// offers a copy of a PNG made from Clipio's own icon, so the practice never touches
/// the user's files.
struct OnboardingDragSample: NSViewRepresentable {
  let onDragStart: () -> Void

  func makeNSView(context: Context) -> DragSampleView {
    let view = DragSampleView()
    view.onDragStart = onDragStart
    view.setAccessibilityIdentifier("onboarding-drag-sample")
    view.setAccessibilityRole(.image)
    view.setAccessibilityLabel(NSLocalizedString("onboarding_drag_sample", comment: ""))
    return view
  }

  func updateNSView(_ view: DragSampleView, context: Context) {
    view.onDragStart = onDragStart
  }
}

final class DragSampleView: NSView, NSDraggingSource {
  var onDragStart: (() -> Void)?
  private var dragging = false
  private static let side: CGFloat = 52

  override var intrinsicContentSize: NSSize { NSSize(width: Self.side, height: Self.side) }
  // The guide window moves by its background; this view must start a drag instead.
  override var mouseDownCanMoveWindow: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    NSApp.applicationIconImage.draw(in: bounds)
  }

  // Keep the press here; passed up the responder chain it would start a window drag.
  override func mouseDown(with event: NSEvent) {}
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .openHand)
  }

  override func mouseDragged(with event: NSEvent) {
    guard !dragging else { return }
    dragging = true
    let icon = NSApp.applicationIconImage ?? NSImage()
    let size = NSSize(width: 256, height: 256)
    let picture = NSImage(size: size, flipped: false) { rect in
      icon.draw(in: rect)
      return true
    }
    guard let tiff = picture.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    else { return }
    let item = NSPasteboardItem()
    item.setData(png, forType: .png)
    let dragging = NSDraggingItem(pasteboardWriter: item)
    dragging.setDraggingFrame(bounds, contents: icon)
    onDragStart?()
    beginDraggingSession(with: [dragging], event: event, source: self)
  }

  func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
    NotificationCenter.default.post(name: CollectionAccessController.internalDragMoved, object: nil)
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    dragging = false
    NotificationCenter.default.post(name: CollectionAccessController.internalDragEnded, object: nil)
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    .copy
  }
}
