import SwiftUI

struct ArtistView: View {
    let artist: Artist
    @State private var tracks: [Track] = []
    @State private var albums: [Album] = []
    @State private var loading = true
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                artistHeader

                HStack(spacing: 10) {
                    Button {
                        if let first = tracks.first {
                            player.play(first, queue: tracks)
                        }
                    } label: {
                        Label("Слушать", systemImage: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(Color.primary, in: Capsule())
                    }

                    NavigationLink {
                        WaveView(seed: tracks.first)
                    } label: {
                        Image(systemName: "waveform")
                            .frame(width: 48, height: 48)
                            .rhythmGlass(24)
                    }
                }

                Text("Популярные треки").sectionTitle()
                if loading {
                    ProgressView().tint(RhythmTheme.accent).frame(maxWidth: .infinity).padding(45)
                } else {
                    VerticalTracks(tracks: Array(tracks.prefix(20)))
                }

                if !albums.isEmpty {
                    Text("Дискография").sectionTitle().padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(albums) { album in
                                NavigationLink {
                                    AlbumView(album: album)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        CoverView(url: album.coverURL, size: 142, radius: 20)
                                        Text(album.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .lineLimit(2)
                                        Text("\(album.type.rawValue) · \(album.trackCount) треков")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(RhythmTheme.secondary)
                                    }
                                    .frame(width: 142, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
            }
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let loadedTracks = MusicCatalog.shared.artistTracks(id: artist.id)
            async let loadedAlbums = MusicCatalog.shared.artistAlbums(id: artist.id)
            tracks = (try? await loadedTracks) ?? []
            albums = (try? await loadedAlbums) ?? []
            loading = false
        }
    }

    private var artistHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL = artist.imageURL ?? tracks.first?.highResCoverURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RhythmTheme.surface
                }
            } else {
                RhythmTheme.surface
            }

            LinearGradient(
                colors: [.clear, RhythmTheme.background.opacity(0.96)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("ИСПОЛНИТЕЛЬ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(RhythmTheme.accent)
                Text(artist.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-1)
                if let genre = artist.genre {
                    Text(genre)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RhythmTheme.secondary)
                }
            }
            .padding(20)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }
}
