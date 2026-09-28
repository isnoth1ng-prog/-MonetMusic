import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared

    @State private var recommendations: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let recommendationService = RecommendationService()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<24: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    private var likedTracks: [Track] {
        libraryTracks.map(\.track)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.monetBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(greeting)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.monetSecondary)

                                Text("Rhythm")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(MonetTheme.accent.opacity(0.14))
                                Image(systemName: "waveform")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(MonetTheme.accent)
                            }
                            .frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, MonetTheme.padding)
                        .padding(.top, 14)

                        NavigationLink {
                            MyWaveView()
                        } label: {
                            HStack(spacing: 18) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 62, height: 62)
                                    Image(systemName: "waveform")
                                        .font(.system(size: 25, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Моя волна")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Музыка на основе того, что ты слушаешь")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.58))
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.monetSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, MonetTheme.padding)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                        } else if let errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Не удалось обновить рекомендации")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(.monetSecondary)
                                Button("Повторить") { loadRecommendations() }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(MonetTheme.accent)
                            }
                            .padding(.horizontal, MonetTheme.padding)
                        } else if !recommendations.isEmpty {
                            TrackCarousel(
                                title: libraryTracks.isEmpty ? "Для первого знакомства" : "Для тебя",
                                subtitle: libraryTracks.isEmpty ? "Начни слушать — Rhythm запомнит вкус" : "Собрано из твоих лайков и истории",
                                tracks: recommendations,
                                size: 172
                            ) { track in
                                audioPlayer.play(track: track, queue: recommendations)
                            }
                        }

                        TrackCarousel(
                            title: "История",
                            subtitle: "Недавно включённые треки",
                            tracks: ListeningHistory.shared.recentTracks(limit: 12),
                            size: 142
                        ) { track in
                            audioPlayer.play(track: track, queue: ListeningHistory.shared.recentTracks(limit: 12))
                        }

                        Spacer(minLength: 110)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await refreshRecommendations()
            }
            .onAppear {
                if recommendations.isEmpty { loadRecommendations() }
            }
        }
    }

    private func loadRecommendations() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            let result = await recommendationService.homeRecommendations(liked: likedTracks)
            await MainActor.run {
                recommendations = result
                isLoading = false
                if result.isEmpty && !likedTracks.isEmpty {
                    errorMessage = "Сервис не вернул подходящих треков."
                }
            }
        }
    }

    private func refreshRecommendations() async {
        let result = await recommendationService.homeRecommendations(liked: likedTracks)
        await MainActor.run {
            recommendations = result
            errorMessage = result.isEmpty ? "Пока нечего рекомендовать." : nil
        }
    }
}

struct TrackCarousel: View {
    let title: String
    let subtitle: String
    let tracks: [Track]
    let size: CGFloat
    let onPlay: (Track) -> Void

    var body: some View {
        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.monetSecondary)
                }
                .padding(.horizontal, MonetTheme.padding)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(tracks) { track in
                            Button {
                                onPlay(track)
                            } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    AsyncCoverImage(url: track.highResCoverURL, size: size)
                                    Text(track.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(track.artist)
                                        .font(.system(size: 12))
                                        .foregroundColor(.monetSecondary)
                                        .lineLimit(1)
                                }
                                .frame(width: size, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, MonetTheme.padding)
                }
            }
        }
    }
}
