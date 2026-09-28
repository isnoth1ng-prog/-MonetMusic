import SwiftUI
import SwiftData

@main
struct MonetMusicApp: App {
    @AppStorage("selectedTheme") private var selectedTheme = "Dark"
    
    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(for: [LibraryTrack.self, UserPlaylist.self])
    }
}
