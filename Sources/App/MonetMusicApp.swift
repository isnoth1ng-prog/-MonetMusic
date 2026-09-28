import SwiftUI
import SwiftData

@main
struct MonetMusicApp: App {
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [LibraryTrack.self, UserPlaylist.self])
    }
}
