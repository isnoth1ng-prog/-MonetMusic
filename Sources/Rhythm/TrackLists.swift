import SwiftUI

struct VerticalTracks: View {
    let tracks: [Track]
    var body: some View {
        LazyVStack(spacing: 3) {
            ForEach(tracks) { track in TrackRow(track: track) }
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
                            Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(track.artist).font(.system(size: 12)).foregroundStyle(RhythmTheme.secondary).lineLimit(1)
                        }.frame(width: 145, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 18)
        }
    }
}

struct TrackRow: View {
    @EnvironmentObject private var player: RhythmPlayer
    let track: Track
    var body: some View {
        HStack(spacing: 12) {
            Button { player.play(track) } label: { CoverView(url: track.highResCoverURL, size: 58, radius: 15) }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(track.artist).font(.system(size: 13, weight: .medium)).foregroundStyle(RhythmTheme.secondary).lineLimit(1)
            }
            Spacer()
            Button { player.toggleLike(track) } label: {
                Image(systemName: player.isLiked(track) ? "heart.fill" : "heart")
                    .foregroundStyle(player.isLiked(track) ? RhythmTheme.accent : RhythmTheme.secondary)
            }.buttonStyle(.plain)
        }.padding(.vertical, 7)
    }
}

struct EmptySearch: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 36)).foregroundStyle(RhythmTheme.accent.opacity(0.65))
            Text(title).font(.system(size: 21, weight: .semibold, design: .rounded))
            Text(subtitle).font(.system(size: 14, weight: .medium)).foregroundStyle(RhythmTheme.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.top, 90)
    }
}

extension Text {
    func sectionTitle() -> some View { self.font(.system(size: 21, weight: .bold, design: .rounded)) }
}
