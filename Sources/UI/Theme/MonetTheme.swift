import SwiftUI

struct MonetTheme {
    // Monet is intentionally restrained: graphite surfaces, white typography,
    // and one cool accent. Color comes from artwork rather than UI decoration.
    static let graphite = Color(red: 22/255, green: 22/255, blue: 24/255)
    static let titanium = Color(red: 31/255, green: 31/255, blue: 34/255)
    static let darkGray = Color(red: 58/255, green: 58/255, blue: 62/255)
    
    static let padding: CGFloat = 20
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 28
    
    static let accent = Color(red: 0.35, green: 0.48, blue: 1.0)
    static let accentSoft = Color(red: 0.35, green: 0.48, blue: 1.0).opacity(0.16)
}

extension Color {
    static let monetBackground = Color(red: 10/255, green: 10/255, blue: 12/255)
    static let monetSurface = Color(red: 22/255, green: 22/255, blue: 25/255)
    static let monetSurfaceElevated = Color(red: 30/255, green: 30/255, blue: 34/255)
    static let monetSecondary = Color(red: 154/255, green: 154/255, blue: 162/255)
    static let monetAccent = MonetTheme.accent
}

struct GlassmorphismModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    func glassmorphism() -> some View {
        modifier(GlassmorphismModifier())
    }
    
    func monetCard(cornerRadius: CGFloat = MonetTheme.cornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.monetSurface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}
