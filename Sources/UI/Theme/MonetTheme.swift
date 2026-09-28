import SwiftUI

struct MonetTheme {
    static let graphite = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let titanium = Color(red: 44/255, green: 44/255, blue: 46/255)
    static let darkGray = Color(red: 72/255, green: 72/255, blue: 74/255)
    
    static let padding: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 24
    
    static let accent = Color.indigo
}

extension Color {
    static let monetBackground = Color(red: 15/255, green: 15/255, blue: 17/255)
    static let monetSurface = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let monetSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let monetAccent = Color.indigo
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
