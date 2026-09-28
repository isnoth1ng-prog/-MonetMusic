import SwiftUI
import SwiftData

@main
struct RhythmApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [LibraryTrack.self, UserPlaylist.self])
    }
}
