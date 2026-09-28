import SwiftUI

@MainActor
final class RhythmAppearance: ObservableObject {
    static let shared = RhythmAppearance()

    @Published private(set) var revision = 0

    private init() {}

    func applyAccent(_ hex: String) {
        let rgb = Color.rgb(hex: hex)
        UserDefaults.standard.set(hex, forKey: "accentHex")
        UserDefaults.standard.set(rgb.r, forKey: "accentR")
        UserDefaults.standard.set(rgb.g, forKey: "accentG")
        UserDefaults.standard.set(rgb.b, forKey: "accentB")
        revision += 1
    }

    func applyTheme(_ mode: String) {
        UserDefaults.standard.set(mode, forKey: "themeMode")
        revision += 1
    }
}

enum RhythmTheme {
    static let background = Color(red: 7/255, green: 8/255, blue: 10/255)
    static let surface = Color(red: 19/255, green: 20/255, blue: 24/255)
    static let surface2 = Color(red: 30/255, green: 31/255, blue: 36/255)
    static let secondary = Color.white.opacity(0.52)
    static let hairline = Color.white.opacity(0.09)

    static var accent: Color {
        let r = UserDefaults.standard.object(forKey: "accentR") as? Double
        let g = UserDefaults.standard.object(forKey: "accentG") as? Double
        let b = UserDefaults.standard.object(forKey: "accentB") as? Double
        return Color(red: r ?? 0.353, green: g ?? 0.549, blue: b ?? 1)
    }

    static var accentSoft: Color { accent.opacity(0.16) }
}

struct CoverView: View {
    let url: URL?
    let size: CGFloat
    var radius: CGFloat = 18

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Rectangle().fill(RhythmTheme.surface2)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.24))
                        .foregroundStyle(.white.opacity(0.25))
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
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.14), .white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}

extension View {
    func rhythmGlass(_ radius: CGFloat = 24) -> some View {
        modifier(GlassCard(radius: radius))
    }

    func rhythmSection() -> some View {
        self.font(.system(size: 22, weight: .bold, design: .rounded))
    }
}

extension Color {
    init(hex: String) {
        let value = Int(hex, radix: 16) ?? 0x5A8CFF
        self.init(
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255
        )
    }

    static func rgb(hex: String) -> (r: Double, g: Double, b: Double) {
        let value = Int(hex, radix: 16) ?? 0x5A8CFF
        return (
            Double((value >> 16) & 255) / 255,
            Double((value >> 8) & 255) / 255,
            Double(value & 255) / 255
        )
    }
}
