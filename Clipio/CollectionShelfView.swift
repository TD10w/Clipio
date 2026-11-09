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
          ForEach(store.visibleItems) { item in
            CollectionCardView(item: item, store: store)
              .id(item.id)
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
        if let id = store.visibleItems.first(where: { ids.contains($0.id) })?.id {
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

private struct CollectionCardView: View {
  let item: CollectionItem
  let store: CollectionStore
  @State private var thumbnail: NSImage?
  @State private var hovered = false

  private var isUnavailable: Bool { store.unavailableIDs.contains(item.id) }
  private var selected: Bool { store.selectedIDs.contains(item.id) }

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
        Text(item.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
        if isUnavailable {
          Text("collection_file_unavailable").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
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
    .overlay {
      RoundedRectangle(cornerRadius: FloatingGlassStyle.cardRadius)
        .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2.5)
        .allowsHitTesting(false)
    }
    .overlay { CollectionDragSource(id: item.id, store: store) }
    .overlay(alignment: .topTrailing) {
      if item.isPinned || hovered {
        Button {
          store.perform { try store.togglePin(item.id) }
        } label: {
          Image(systemName: item.isPinned ? "pin.fill" : "pin")
            .font(.system(size: 11, weight: .medium))
            .frame(width: 28, height: 28)
            .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(Text(item.isPinned ? "collection_unpin" : "collection_pin"))
        .accessibilityIdentifier("collection-pin-\(item.id)")
        .padding(5)
      }
    }
    .contextMenu {
      Button(item.isPinned ? "collection_unpin" : "collection_pin") {
        store.perform { try store.togglePin(item.id) }
      }
      Button("collection_select_all") { store.selectedIDs = Set(store.visibleItems.map(\.id)) }
      Button("collection_remove", role: .destructive) {
        let ids = selected ? store.selectedIDs : [item.id]
        store.perform { try store.remove(ids: ids) }
      }
    }
    .onHover { hovered = $0 }
    .task(id: isUnavailable) {
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
    .accessibilityIdentifier("collection-item")
    .accessibilityLabel(Text(item.name))
    .accessibilityValue(Text(item.isPinned ? "collection_pinned" : "collection_unpinned"))
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityAction { store.select(item.id, extending: false) }
  }
}
