import SwiftUI

enum RhythmTheme {
    static let background = Color(red: 7/255, green: 8/255, blue: 10/255)
    static let surface = Color(red: 19/255, green: 20/255, blue: 24/255)
    static let surface2 = Color(red: 30/255, green: 31/255, blue: 36/255)
    static let secondary = Color.white.opacity(0.52)
    static let hairline = Color.white.opacity(0.08)

    static var accent: Color {
        let r = UserDefaults.standard.object(forKey: "accentR") as? Double
        let g = UserDefaults.standard.object(forKey: "accentG") as? Double
        let b = UserDefaults.standard.object(forKey: "accentB") as? Double
        return Color(red: r ?? 0.35, green: g ?? 0.55, blue: b ?? 1)
    }
}

struct CoverView: View {
    let url: URL?
    let size: CGFloat
    var radius: CGFloat = 18

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default:
                ZStack {
                    Rectangle().fill(RhythmTheme.surface2)
                    Image(systemName: "music.note").font(.system(size: size * 0.24)).foregroundStyle(.white.opacity(0.25))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct GlassCard: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.7))
    }
}

extension View {
    func rhythmGlass(_ radius: CGFloat = 24) -> some View { modifier(GlassCard(radius: radius)) }
}
