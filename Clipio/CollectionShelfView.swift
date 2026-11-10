import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct CollectionShelfView: View {
  @Bindable var store: CollectionStore
  @State private var isTargeted = false

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: FloatingGlassStyle.cardSpacing) {
          ForEach(store.visibleEntries) { entry in
            Group {
              switch entry {
              case .single(let item):
                CollectionCardView(members: [item], batchID: nil, store: store)
              case .stack(let batch, let members):
                CollectionCardView(members: members, batchID: batch, store: store)
              case .collapseHandle(let batch, let count):
                CollectionStackCollapseHandle(count: count) {
                  withAnimation(.snappy(duration: 0.25)) { store.toggleExpanded(batch) }
                }
              }
            }
            .id(entry.id)
          }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
      }
      .overlay {
        if store.visibleItems.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down").font(.system(size: 26))
            Text(store.searchQuery.isEmpty ? "collection_empty" : "collection_no_results")
              .font(.system(size: 13))
          }
          .foregroundStyle(.secondary)
          .allowsHitTesting(false)
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if store.importingCount > 0 {
          ProgressView().controlSize(.small).padding(12)
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: FloatingGlassStyle.cardRadius)
          .strokeBorder(isTargeted ? Color.accentColor : .clear, lineWidth: 2)
          .allowsHitTesting(false)
      }
      .onDrop(of: CollectionImporter.supportedTypes, isTargeted: $isTargeted) { providers in
        guard !store.isExporting else { return false }
        Task { await CollectionImporter.collect(providers, into: store) }
        return true
      }
      .onChange(of: store.selectedIDs) { _, ids in
        if let id = store.visibleEntries.first(where: { !$0.itemIDs.isDisjoint(with: ids) })?.id {
          withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
        }
      }
    }
    .frame(height: FloatingGlassStyle.cardHeight + 22)
    .onAppear {
      AppState.shared.appDelegate?.panel.finishPrewarming()
      store.refreshAvailability()
    }
    .confirmationDialog("collection_clear_confirm", isPresented: $store.showClearConfirmation) {
      Button("collection_clear", role: .destructive) {
        store.perform { try store.clearUnpinned() }
      }
      .accessibilityIdentifier("confirm-clear-collection")
      Button("Cancel", role: .cancel) {}
    }
    .alert("collection_error_title", isPresented: Binding(
      get: { store.lastError != nil },
      set: { if !$0 { store.lastError = nil } }
    )) {
      Button("OK") { store.lastError = nil }
    } message: {
      Text(store.lastError ?? "")
    }
    .accessibilityIdentifier("collection-shelf")
  }
}

/// A single item card, or a collapsed Stack when `batchID` is set (front card shows the
/// first member; click expands, drag/Pin act on the whole Stack).
private struct CollectionCardView: View {
  let members: [CollectionItem]
  let batchID: UUID?
  let store: CollectionStore
  @State private var thumbnail: NSImage?
  @State private var hovered = false

  private var item: CollectionItem { members[0] }
  private var ids: Set<UUID> { Set(members.map(\.id)) }
  private var isStack: Bool { batchID != nil }
  private var isUnavailable: Bool { !isStack && store.unavailableIDs.contains(item.id) }
  private var selected: Bool { ids.isSubset(of: store.selectedIDs) }
  private var isPinned: Bool { members.allSatisfy(\.isPinned) }
  private var title: String {
    isStack ? String(format: NSLocalizedString("collection_stack_count", comment: ""), members.count) : item.name
  }

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        if let thumbnail {
          Image(nsImage: thumbnail).resizable().scaledToFit().padding(14)
        } else {
          Image(systemName: isUnavailable ? "exclamationmark.triangle" : "doc")
            .font(.system(size: 36)).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: FloatingGlassStyle.cardBodyFontSize, weight: .medium))
          .lineLimit(2)
        if isUnavailable {
          Text("collection_file_unavailable")
            .font(.system(size: FloatingGlassStyle.metadataFontSize))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(Color.primary.opacity(0.04))
    }
    .frame(width: FloatingGlassStyle.cardWidth, height: FloatingGlassStyle.cardHeight)
    .clipShape(RoundedRectangle(cornerRadius: FloatingGlassStyle.cardRadius))
    .modifier(FloatingGlassCardBackground(isHovered: hovered))
    .background {
      // Two offset plates behind the front card read as a pile.
      if isStack {
        ZStack {
          stackPlate.offset(x: 8, y: -7).opacity(0.55)
          stackPlate.offset(x: 4, y: -3.5).opacity(0.8)
        }
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: FloatingGlassStyle.cardRadius)
        .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
        .allowsHitTesting(false)
    }
    .overlay {
      CollectionDragSource(ids: members.map(\.id), store: store, onClick: batchID.map { batch in
        { withAnimation(.snappy(duration: 0.25)) { store.toggleExpanded(batch) } }
      })
    }
    .overlay(alignment: .topLeading) {
      if isStack {
        Text("\(members.count)")
          .font(.system(size: 11, weight: .semibold))
          .monospacedDigit()
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(.regularMaterial, in: Capsule())
          .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
          .padding(7)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .overlay(alignment: .topTrailing) {
      if isPinned || hovered {
        Button {
          store.perform { try store.togglePin(ids: ids) }
        } label: {
          Image(systemName: isPinned ? "pin.fill" : "pin")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isPinned ? Color.accentColor : .primary)
            .frame(width: 28, height: 28)
            .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(Text(isPinned ? "collection_unpin" : "collection_pin"))
        .accessibilityIdentifier("collection-pin-\(item.id)")
        .padding(5)
      }
    }
    .contextMenu {
      if let batchID {
        Button("collection_stack_expand") {
          withAnimation(.snappy(duration: 0.25)) { store.toggleExpanded(batchID) }
        }
      }
      Button(isPinned ? "collection_unpin" : "collection_pin") {
        store.perform { try store.togglePin(ids: ids) }
      }
      Button("collection_select_all") { store.selectedIDs = Set(store.visibleItems.map(\.id)) }
      Button("collection_remove", role: .destructive) {
        let removing = selected ? store.selectedIDs : ids
        store.perform { try store.remove(ids: removing) }
      }
    }
    .onHover { hovered = $0 }
    .task(id: "\(item.id)-\(isUnavailable)") {
      guard !isUnavailable, let url = try? store.resolveURL(for: item.id) else { return }
      let accessed = url.startAccessingSecurityScopedResource()
      defer { if accessed { url.stopAccessingSecurityScopedResource() } }
      // Decode a small preview away from the UI thread; large photos never become full-size card bitmaps.
      let preview = await Task.detached(priority: .utility) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return Optional<CGImage>.none }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: 240,
          kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary)
      }.value
      guard !Task.isCancelled else { return }
      thumbnail = preview.map { NSImage(cgImage: $0, size: .zero) } ?? NSWorkspace.shared.icon(forFile: url.path)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(isStack ? "collection-stack" : "collection-item")
    .accessibilityLabel(Text(title))
    .accessibilityValue(Text(isPinned ? "collection_pinned" : "collection_unpinned"))
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityAction {
      if let batchID { store.toggleExpanded(batchID) } else { store.select(item.id, extending: false) }
    }
  }

  private var stackPlate: some View {
    RoundedRectangle(cornerRadius: FloatingGlassStyle.cardRadius, style: .continuous)
      .fill(.regularMaterial)
      .overlay(
        RoundedRectangle(cornerRadius: FloatingGlassStyle.cardRadius, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
      )
  }
}

/// Leads an expanded Stack's members; clicking it folds them back into one card.
private struct CollectionStackCollapseHandle: View {
  let count: Int
  let action: () -> Void
  @State private var hovered = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: "chevron.left")
          .font(.system(size: 12, weight: .semibold))
        Text("\(count)")
          .font(.system(size: 11, weight: .semibold))
          .monospacedDigit()
      }
      .foregroundStyle(hovered ? .primary : .secondary)
      .frame(width: 30, height: FloatingGlassStyle.cardHeight)
      .background(.regularMaterial, in: Capsule())
      .overlay(Capsule().strokeBorder(Color.primary.opacity(hovered ? 0.2 : 0.08), lineWidth: 1))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .onHover { hovered = $0 }
    .help(Text("collection_stack_collapse"))
    .accessibilityLabel(Text("collection_stack_collapse"))
    .accessibilityIdentifier("collection-stack-collapse")
  }
}
