import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 11) {
                    CoverView(url: player.currentTrack?.highResCoverURL, size: 46, radius: 13)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.currentTrack?.title ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(player.currentTrack?.artist ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(Color.primary, in: Circle())
                    .foregroundStyle(RhythmTheme.background)
            }
        }
        .padding(6)
        .rhythmGlass(20)
        .padding(.horizontal, 2)
    }
}
