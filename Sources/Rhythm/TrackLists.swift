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
