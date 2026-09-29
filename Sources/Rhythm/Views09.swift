import SwiftUI

struct AdaptivePlayerBackground: View {
    let url: URL?

    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable()
                        .scaledToFill()
                        .blur(radius: 70)
                        .opacity(0.30)
                }
            }

            LinearGradient(
                colors: [RhythmTheme.background.opacity(0.12), RhythmTheme.background.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

struct VerticalTracks: View {
    let tracks: [Track]

    var body: some View {
        LazyVStack(spacing: 3) {
            ForEach(tracks) { track in
                TrackRow(track: track)
            }
        }
    }
}

struct HorizontalTracks: View {
    @EnvironmentObject private var player: RhythmPlayer
    let tracks: [Track]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(tracks) { track in
                    Button { player.play(track, queue: tracks) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            CoverView(url: track.highResCoverURL, size: 145, radius: 20)
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(RhythmTheme.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 145, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }
}

struct TrackRow: View {
    @EnvironmentObject private var player: RhythmPlayer
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            Button { player.play(track) } label: {
                CoverView(url: track.highResCoverURL, size: 58, radius: 15)
            }
            .buttonStyle(.plain)

            Button { player.play(track) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        if track.isExplicit {
                            Text("E")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RhythmTheme.secondary.opacity(0.16), in: Capsule())
                        }
                    }
                    Text(track.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RhythmTheme.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    player.toggleLike(track)
                } label: {
                    Label(
                        player.isLiked(track) ? "Убрать из любимого" : "В любимое",
                        systemImage: player.isLiked(track) ? "heart.slash" : "heart"
                    )
                }

                NavigationLink {
                    WaveView(seed: track)
                } label: {
                    Label("Моя волна по треку", systemImage: "waveform")
                }

                if let artistID = track.artistID {
                    NavigationLink {
                        ArtistView(
                            artist: Artist(
                                id: artistID,
                                name: track.artist,
                                genre: track.genre,
                                imageURL: track.highResCoverURL
                            )
                        )
                    } label: {
                        Label("Исполнитель", systemImage: "person")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(RhythmTheme.secondary)
                    .frame(width: 32, height: 40)
            }
        }
        .padding(.vertical, 7)
    }
}

struct EmptySearch: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 36))
                .foregroundStyle(RhythmTheme.accent.opacity(0.65))
            Text(title)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RhythmTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

extension Text {
    func sectionTitle() -> some View {
        self.font(.system(size: 21, weight: .bold, design: .rounded))
    }
}