import SwiftUI

struct SearchFieldView: View {
  var placeholder: LocalizedStringKey
  @Binding var query: String

  @Environment(AppState.self) private var appState

  var body: some View {
    ZStack {
      searchSurface

      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 13, weight: .medium))
          .frame(width: 14, height: 14)
          .padding(.leading, 10)
          .opacity(0.78)

        TextField(placeholder, text: $query)
          .disableAutocorrection(true)
          .lineLimit(1)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .foregroundStyle(.primary)
          .tint(.primary)
          .onSubmit {
            appState.select()
          }

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .frame(width: 13, height: 13)
              .padding(.trailing, 9)
          }
          .buttonStyle(.plain)
          .opacity(0.9)
        }
      }
    }
    .frame(height: FloatingGlassStyle.searchHeight)
  }

  @ViewBuilder
  private var searchSurface: some View {
    let radius = FloatingGlassStyle.searchHeight / 2
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

    if #available(macOS 26.0, *) {
      // A light frosted fill (not fully clear) gives the typed text something to
      // sit on so the glyphs stay crisp instead of washing into the glass.
      Color.white.opacity(0.12)
        .glassEffect(.regular, in: .rect(cornerRadius: radius))
        .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8))
    } else {
      shape
        .fill(.ultraThinMaterial)
        .overlay(shape.fill(FloatingGlassStyle.cardTint.opacity(0.12)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.32), lineWidth: 0.8))
    }
  }
}

#Preview {
  return List {
    SearchFieldView(placeholder: "search_placeholder", query: .constant(""))
    SearchFieldView(placeholder: "search_placeholder", query: .constant("search"))
  }
  .frame(width: 300)
  .environment(\.locale, .init(identifier: "en"))
}
