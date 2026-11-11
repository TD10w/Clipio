import SwiftUI

/// Synthetic examples, deliberately independent of History and CollectionStore.
struct OnboardingIllustration: View {
  let page: Int
  let menuIcon: MenuIcon

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.accentColor.opacity(0.055))
      if page == 0 { menuBar } else { shelf }
    }
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private var menuBar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 18) {
        Image(systemName: "apple.logo")
        Text(verbatim: "Finder").fontWeight(.semibold)
        Text(verbatim: "File")
        Text(verbatim: "Edit")
        Spacer()
        Group {
          if menuIcon == .scissors {
            Text(verbatim: "✂︎").font(.system(size: 17))
          } else {
            Image(nsImage: menuIcon.image)
              .resizable()
              .scaledToFit()
              .frame(width: 18, height: 18)
          }
        }
        .frame(width: 30, height: 26)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.accentColor, lineWidth: 2))
        .overlay(alignment: .bottom) {
          VStack(spacing: 0) {
            Image(systemName: "arrow.up")
              .font(.system(size: 30, weight: .light))
              .frame(height: 55)
            Text("onboarding_entry_callout")
              .font(.system(size: 12, weight: .medium))
              .fixedSize()
              .padding(.horizontal, 13)
              .padding(.vertical, 10)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
          }
          .foregroundStyle(Color.accentColor)
          .offset(y: 98)
        }
        Image(systemName: "wifi")
        Text(verbatim: "9:41")
      }
      .font(.system(size: 11))
      .padding(.horizontal, 17)
      .frame(height: 34)
      .background(.regularMaterial)
      Spacer()
      HStack {
        Text("onboarding_menu_bar_example")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(18)
    }
  }

  private var shelf: some View {
    VStack(spacing: 18) {
      VStack(spacing: 12) {
        HStack {
          Image(systemName: page == 1 ? "clipboard" : "tray")
          Text(page == 1 ? "onboarding_clipboard_title" : "onboarding_collection_title")
          Spacer()
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        }
        .font(.system(size: 11, weight: .medium))
        HStack(spacing: 10) {
          if page == 1 { clipboardCards } else { fileCards }
        }
        .frame(height: 95)
      }
      .padding(13)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
      .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.primary.opacity(0.08)))
      if page == 2 {
        HStack(spacing: 9) {
          Image(systemName: "doc")
          Image(systemName: "arrow.right")
          Image(systemName: "tray")
          Image(systemName: "arrow.right")
          Image(systemName: "folder")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      }
    }
    .padding(22)
  }

  private var clipboardCards: some View {
    Group {
      VStack(alignment: .leading, spacing: 9) {
        Text(verbatim: "Weekend plans").fontWeight(.medium)
        Text(verbatim: "Bring the camera.").foregroundStyle(.secondary)
        Spacer(minLength: 0)
      }
      .font(.system(size: 11))
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(.background, in: RoundedRectangle(cornerRadius: 9))

      Image(systemName: "photo")
        .font(.system(size: 35, weight: .ultraLight))
        .foregroundStyle(Color.accentColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

      Text(verbatim: "#A8C8F0")
        .font(.system(size: 11, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(12)
        .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 9))
    }
  }

  private var fileCards: some View {
    ForEach(["Trip.pdf", "Photo.jpg", "Files"], id: \.self) { name in
      VStack(spacing: 9) {
        Image(systemName: name == "Files" ? "folder.fill" : "doc.fill")
          .font(.system(size: 29, weight: .light))
          .foregroundStyle(Color.accentColor.opacity(0.8))
        Text(verbatim: name).font(.system(size: 10))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.background, in: RoundedRectangle(cornerRadius: 9))
    }
  }
}
