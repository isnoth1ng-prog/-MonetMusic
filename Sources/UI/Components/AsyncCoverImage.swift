import SwiftUI

struct AsyncCoverImage: View {
    let url: URL?
    var cornerRadius: CGFloat = MonetTheme.cornerRadius
    var size: CGFloat? = nil
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Color.monetSurface
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                ZStack {
                    Color.monetSurface
                    Image(systemName: "music.note")
                        .foregroundColor(.monetSecondary)
                }
            @unknown default:
                Color.monetSurface
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
