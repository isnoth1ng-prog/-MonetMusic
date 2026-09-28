import SwiftUI

struct MonetTheme {
    static let graphite = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let titanium = Color(red: 44/255, green: 44/255, blue: 46/255)
    static let darkGray = Color(red: 72/255, green: 72/255, blue: 74/255)

    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 24
    static let accent = Color(red: 0.32, green: 0.55, blue: 1.0)
}

extension Color {
    static let monetBackground = Color(red: 12/255, green: 13/255, blue: 16/255)
    static let monetSurface = Color(red: 23/255, green: 24/255, blue: 29/255)
    static let monetSecondary = Color(red: 151/255, green: 153/255, blue: 162/255)
    static let monetAccent = Color(red: 0.32, green: 0.55, blue: 1.0)
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
}
