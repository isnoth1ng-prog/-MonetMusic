import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private let musicService: MusicService = ITunesMusicService()
    @StateObject private var audioPlayer = AudioPlayerService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.monetBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.monetSecondary)

                        TextField("Трек, артист, альбом", text: $query)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: query) { _, _ in debounceSearch() }
                            .onSubmit { performSearch() }

                        if !query.isEmpty {
                            Button {
                                searchTask?.cancel()
                                query = ""
                                results = []
                                errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.monetSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.monetSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, MonetTheme.padding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if let errorMessage {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 30))
                                .foregroundColor(.monetSecondary)
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.monetSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                            Button("Повторить") { performSearch() }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MonetTheme.accent)
                        }
                        Spacer()
                    } else if results.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.system(size: 42))
                                .foregroundColor(.monetSecondary.opacity(0.5))
                            Text(query.isEmpty ? "Найди музыку" : "Ничего не найдено")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            if query.isEmpty {
                                Text("Ищи по названию трека или артисту")
                                    .font(.system(size: 13))
                                    .foregroundColor(.monetSecondary)
                            }
                        }
                        Spacer()
                    } else {
                        HStack {
                            Text("\(results.count) треков")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.monetSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, MonetTheme.padding)
                        .padding(.bottom, 4)

                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(results) { track in
                                    TrackRowView(track: track) {
                                        audioPlayer.play(track: track, queue: results)
                                    }
                                }
                            }
                            .padding(.bottom, 110)
                        }
                    }
                }
            }
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()

        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run { performSearch() }
        }
    }

    private func performSearch() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        searchTask?.cancel()
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetched = try await musicService.search(query: value)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = fetched
                    isLoading = false
                    if fetched.isEmpty {
                        errorMessage = "По запросу «\(value)» ничего не найдено."
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = []
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
