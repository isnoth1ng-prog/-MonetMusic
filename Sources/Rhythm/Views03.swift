import SwiftUI

struct WaveView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @EnvironmentObject private var store: ListeningStore
    let seed: Track?

    @State private var loading = false
    @State private var started = false
    @State private var current: Track?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ZStack {
                    if let url = (player.currentTrack ?? seed)?.highResCoverURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill().blur(radius: 45).opacity(0.35)
                            }
                        }
                    }

                    LinearGradient(
                        colors: [RhythmTheme.accent.opacity(0.16), RhythmTheme.background.opacity(0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: 22) {
                        WaveMark()
                            .stroke(RhythmTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 150, height: 86)
                        Text(seed == nil ? "RHYTHM WAVE" : "WAVE FROM TRACK")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2.8)
                            .foregroundStyle(RhythmTheme.secondary)
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .rhythmGlass(32)

                VStack(spacing: 8) {
                    Text(seed == nil ? "Моя волна" : "Моя волна по треку")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(-1)
                    Text(
                        seed == nil
                        ? "Не плейлист из 30 песен. Каждый следующий трек появляется после анализа текущего."
                        : "Rhythm расширяет настроение этого трека и решает, что поставить дальше."
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RhythmTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                }

                HStack(spacing: 8) {
                    WaveSignal(title: "Слушал", icon: "headphones")
                    WaveSignal(title: "Пропустил", icon: "forward.end")
                    WaveSignal(title: "Лайкнул", icon: "heart")
                }

                Button {
                    start()
                } label: {
                    HStack(spacing: 9) {
                        if loading {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: started ? "arrow.clockwise" : "play.fill")
                        }
                        Text(started ? "Запустить заново" : "Слушать волну")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.primary, in: Capsule())
                }
                .disabled(loading)

                if let track = player.currentTrack ?? current {
                    HStack(spacing: 13) {
                        CoverView(url: track.highResCoverURL, size: 58, radius: 15)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("СЕЙЧАС В ВОЛНЕ")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(RhythmTheme.accent)
                            Text(track.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: player.isPlaying ? "waveform" : "pause")
                            .foregroundStyle(RhythmTheme.accent)
                    }
                    .padding(12)
                    .rhythmGlass(19)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Моя волна")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: player.currentTrack) { _, value in
            if started { current = value }
        }
    }

    private func start() {
        loading = true
        Task {
            let track = await MusicCatalog.shared.initialWaveTrack(
                seed: seed,
                favorites: store.favorites,
                history: store.history
            )
            await MainActor.run {
                loading = false
                guard let track else { return }
                current = track
                started = true
                player.startWave(track)
            }
        }
    }
}

struct WaveSignal: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(RhythmTheme.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .rhythmGlass(16)
    }
}

struct WaveMark: Shape {
    func path(in rect: CGRect) -> Path {
        let bars = [0.28, 0.56, 0.92, 0.48, 0.74, 0.38, 0.66, 0.46, 0.82]
        var path = Path()
        let gap = rect.width / CGFloat(bars.count * 2)
        for (index, value) in bars.enumerated() {
            let x = gap + CGFloat(index * 2) * gap
            let h = rect.height * value
            path.move(to: CGPoint(x: x, y: rect.midY - h / 2))
            path.addLine(to: CGPoint(x: x, y: rect.midY + h / 2))
        }
        return path
    }
}
