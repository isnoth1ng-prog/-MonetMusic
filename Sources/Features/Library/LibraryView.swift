import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LibraryTrack.addedAt, order: .reverse) private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.monetBackground.ignoresSafeArea()
                
                if libraryTracks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.monetSecondary.opacity(0.5))
                        Text("Здесь пока пусто")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Добавляйте понравившиеся треки, и они появятся здесь.")
                            .font(.system(size: 14))
                            .foregroundColor(.monetSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(libraryTracks) { libTrack in
                                let track = libTrack.track
                                TrackRowView(track: track) {
                                    audioPlayer.play(track: track, queue: libraryTracks.map { $0.track })
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Медиатека")
        }
    }
}
