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

  private var searchSurface: some View {
    let radius = FloatingGlassStyle.searchHeight / 2
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

    // Solid material (not glass) so the typed text stays crisp and it adapts to
    // light/dark on its own.
    return shape
      .fill(.regularMaterial)
      .overlay(shape.strokeBorder(Color.primary.opacity(0.20), lineWidth: 0.8))
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
