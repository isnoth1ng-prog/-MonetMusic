import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ListeningStore
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                        Text("Rhythm")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .tracking(-1)
                    }
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(RhythmTheme.accent)
                        .frame(width: 46, height: 46)
                        .rhythmGlass(23)
                }

                NavigationLink {
                    WaveView(seed: nil)
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        if let url = player.currentTrack?.highResCoverURL {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill().blur(radius: 34).opacity(0.32)
                                }
                            }
                        }
                        LinearGradient(
                            colors: [RhythmTheme.accent.opacity(0.10), RhythmTheme.background.opacity(0.86)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("МОЯ ВОЛНА")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(2)
                                        .foregroundStyle(RhythmTheme.accent)
                                    Text("Музыка, которая меняется вместе с тобой")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .tracking(-0.4)
                                }
                                Spacer()
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(RhythmTheme.accent)
                                    .frame(width: 54, height: 54)
                                    .rhythmGlass(28)
                            }

                            WaveShape()
                                .stroke(
                                    RhythmTheme.accent.opacity(0.75),
                                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                                )
                                .frame(height: 46)

                            Text("Следующий трек выбирается после твоего прослушивания.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                        }
                        .padding(21)
                    }
                    .frame(height: 235)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .rhythmGlass(30)
                }
                .buttonStyle(.plain)

                if !store.favorites.isEmpty {
                    Text("Любимое").sectionTitle()
                    HorizontalTracks(tracks: Array(store.favorites.prefix(10)))
                }

                if !store.history.isEmpty {
                    Text("Недавно слушал").sectionTitle()
                    VerticalTracks(tracks: Array(store.history.prefix(8)))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Начни слушать")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Rhythm будет учитывать прослушивания, пропуски и лайки для твоей волны.")
                            .foregroundStyle(RhythmTheme.secondary)
                    }
                    .padding(.vertical, 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 6..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<24: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }
}

struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        for x in stride(from: 0, through: rect.width, by: 3) {
            let y = rect.midY + sin(x / max(rect.width, 1) * .pi * 4) * rect.height * 0.34
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}
