import SwiftUI

struct CleanFullPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var lyricsMode = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CleanPlayerBackground()
                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Spacer()
                        VStack(spacing: 3) {
                            Text("СЕЙЧАС ИГРАЕТ")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.5)
                            Text(player.sourceLabel.uppercased())
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(RhythmTheme.accent)
                        }
                        Spacer()
                        Button { player.toggleLike() } label: {
                            Image(systemName: "heart")
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .frame(height: 56)

                    ZStack(alignment: .topTrailing) {
                        if lyricsMode && !player.lyrics.isEmpty {
                            CleanLyricsView(lines: player.lyrics, progress: player.progress)
                        } else {
                            CoverView(url: player.currentTrack?.highResCoverURL,
                                      size: min(geo.size.width - 52, 330), radius: 26)
                                .frame(maxWidth: .infinity)
                        }
                        if !player.lyrics.isEmpty {
                            Button { withAnimation(.easeInOut(duration: 0.2)) { lyricsMode.toggle() } } label: {
                                Image(systemName: lyricsMode ? "photo" : "quote.bubble.fill")
                                    .frame(width: 38, height: 38)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                    }
                    .frame(height: min(max(geo.size.height * 0.38, 220), 320))
                    .clipped()

                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.currentTrack?.title ?? "")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .lineLimit(2)
                        Text(player.currentTrack?.artist ?? "")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                    Slider(value: Binding(get: { player.progress }, set: { player.seek($0) }),
                           in: 0...max(player.duration, 1))
                        .tint(RhythmTheme.accent)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                    HStack(spacing: 28) {
                        Button { player.shuffle.toggle() } label: { Image(systemName: "shuffle") }
                        Button { player.previous() } label: { Image(systemName: "backward.fill") }
                        Button { player.toggle() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundStyle(RhythmTheme.background)
                                .frame(width: 64, height: 64)
                                .background(Color.primary, in: Circle())
                        }
                        Button { player.next() } label: { Image(systemName: "forward.fill") }
                        Button { player.cycleRepeat() } label: { Image(systemName: player.repeatMode.icon) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(Color.primary)
    }
}
