import SwiftUI
import SwiftData

struct MyWaveView: View {
    @Query private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared

    @State private var recommendations: [Track] = []
    @State private var isLoading = false
    @State private var selectedMood = "Любое"

    private let recommendationService = RecommendationService()

    private let moods: [(name: String, icon: String)] = [
        ("Любое", "sparkles"),
        ("Бодрое", "bolt.fill"),
        ("Грустное", "cloud.rain.fill"),
        ("Спокойное", "leaf.fill"),
        ("Для тренировки", "flame.fill")
    ]

    private var likedTracks: [Track] {
        libraryTracks.map(\.track)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.monetBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        VStack(spacing: 8) {
                            Text("Моя волна")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Rhythm собирает поток из твоей истории и лайков")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.monetSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 18)
                        .padding(.horizontal, 24)

                        Button {
                            startWave()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 118, height: 118)
                                    .shadow(color: MonetTheme.accent.opacity(0.28), radius: 30)

                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(1.2)
                                } else {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .disabled(isLoading)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Настроение")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(moods, id: \.name) { mood in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedMood = mood.name
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: mood.icon)
                                                Text(mood.name)
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(selectedMood == mood.name ? .black : .white.opacity(0.72))
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(selectedMood == mood.name ? Color.white : Color.white.opacity(0.07))
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        if !recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Следующие треки")
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)

                                LazyVStack(spacing: 2) {
                                    ForEach(recommendations) { track in
                                        TrackRowView(track: track) {
                                            audioPlayer.play(track: track, queue: recommendations)
                                        }
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 32))
                                    .foregroundColor(.monetSecondary)
                                Text(libraryTracks.isEmpty ? "Нажми play — Rhythm начнёт собирать твою волну." : "Нажми play, чтобы пересобрать поток.")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.monetSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            .padding(.top, 20)
                        }

                        Spacer(minLength: 110)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func startWave() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let result = try await recommendationService.makeWave(
                    liked: likedTracks,
                    mood: selectedMood == "Любое" ? nil : selectedMood
                )

                await MainActor.run {
                    recommendations = result
                    isLoading = false

                    if let first = result.first {
                        audioPlayer.play(track: first, queue: result)
                    }
                }
            } catch {
                await MainActor.run {
                    recommendations = []
                    isLoading = false
                }
            }
        }
    }
}
