import SwiftUI

struct AlbumView: View {
    let album: Album
    @State private var tracks: [Track] = []
    @State private var loading = true
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    CoverView(url: album.coverURL, size: 160, radius: 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(album.type.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(RhythmTheme.accent)
                        Text(album.title)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .lineLimit(4)
                        Text(album.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                        if let date = album.releaseDate {
                            Text(date.formatted(.dateTime.year()))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    guard let first = tracks.first else { return }
                    player.play(first, queue: tracks)
                } label: {
                    Label("Слушать релиз", systemImage: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.primary, in: Capsule())
                }

                Text("\(tracks.count) треков").sectionTitle()

                if loading {
                    ProgressView().tint(RhythmTheme.accent).frame(maxWidth: .infinity).padding(50)
                } else {
                    VerticalTracks(tracks: tracks)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tracks = (try? await MusicCatalog.shared.albumTracks(id: album.id)) ?? []
            loading = false
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: ListeningStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if store.favorites.isEmpty {
                    EmptySearch(title: "Любимое пока пусто", subtitle: "Нажимай сердечко на треках, которые хочешь сохранить.")
                } else {
                    Text("Треки").sectionTitle()
                    VerticalTracks(tracks: store.favorites)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Любимое")
        .navigationBarTitleDisplayMode(.large)
    }
}
