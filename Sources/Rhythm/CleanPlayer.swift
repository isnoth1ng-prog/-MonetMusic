import SwiftUI

struct CleanFullPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var lyricsMode = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    CleanPlayerBackground()
                    VStack(spacing: 0) {
                        header.frame(height: 60)
                        Spacer(minLength: 8)
                        media.frame(height: min(max(geo.size.height * 0.40, 280), 370))
                        titleBlock.padding(.horizontal, 20).padding(.top, 14)
                        progressBlock.padding(.horizontal, 18).padding(.top, 5)
                        controls.padding(.top, 5)
                        Spacer(minLength: 14)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .foregroundStyle(Color.primary)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            VStack(spacing: 3) {
                Text("СЕЙЧАС ИГРАЕТ").font(.system(size: 9, weight: .bold)).tracking(1.7)
                Text(player.sourceLabel.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(player.status == .failed ? Color.red.opacity(0.85) : RhythmTheme.accent)
            }
            Spacer()
            Button { player.toggleLike() } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .buttonStyle(.plain)
    }

    private var isLiked: Bool {
        guard let track = player.currentTrack else { return false }
        return player.isLiked(track)
    }

    private var media: some View {
        ZStack(alignment: .topTrailing) {
            if lyricsMode && !player.lyrics.isEmpty {
                CleanLyricsView(lines: player.lyrics, progress: player.progress)
                    .padding(.horizontal, 8)
            } else {
                CoverView(url: player.currentTrack?.highResCoverURL, size: 1, radius: 26)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(player.currentTrack?.title ?? "Выбери трек")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(2)

            if let track = player.currentTrack, let artistID = track.artistID {
                NavigationLink {
                    ArtistView(artist: Artist(id: artistID, name: track.artist, genre: track.genre, imageURL: nil))
                } label: {
                    HStack(spacing: 5) {
                        Text(track.artist)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RhythmTheme.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text(player.currentTrack?.artist ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(RhythmTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBlock: some View {
        VStack(spacing: 2) {
            Slider(value: Binding(get: { player.progress }, set: { player.seek($0) }), in: 0...max(player.duration, 1))
                .tint(RhythmTheme.accent)
            HStack {
                Text(time(player.progress))
                Spacer()
                Text(time(player.duration))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(RhythmTheme.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 25) {
            Button { player.shuffle.toggle() } label: { Image(systemName: "shuffle").foregroundStyle(player.shuffle ? RhythmTheme.accent : Color.primary) }
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(RhythmTheme.background)
                    .frame(width: 68, height: 68)
                    .background(Color.primary, in: Circle())
            }
            Button { player.next() } label: { Image(systemName: "forward.fill") }
            Button { player.cycleRepeat() } label: { Image(systemName: player.repeatMode.icon).foregroundStyle(player.repeatMode != .off ? RhythmTheme.accent : Color.primary) }
        }
        .font(.system(size: 19, weight: .semibold))
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func time(_ value: Double) -> String {
        let total = max(0, Int(value.isFinite ? value.rounded() : 0))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
