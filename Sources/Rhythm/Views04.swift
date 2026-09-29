import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @State private var query = ""
    @State private var task: Task<Void, Never>?
    @State private var tracks: [Track] = []
    @State private var artists: [Artist] = []
    @State private var loading = false
    @State private var hasSearched = false
    @State private var error: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SearchField(query: $query) { performSearch() }
                    .padding(.top, 6)

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptySearch(title: "Найди музыку", subtitle: "Треки, исполнители, альбомы и EP.")
                } else if loading {
                    VStack(spacing: 12) {
                        ProgressView().tint(RhythmTheme.accent)
                        Text("Ищу музыку…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 90)
                } else if let error {
                    Text(error)
                        .foregroundStyle(RhythmTheme.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 90)
                } else if hasSearched && tracks.isEmpty && artists.isEmpty {
                    EmptySearch(title: "Ничего не нашлось", subtitle: "Попробуй название трека или имя исполнителя.")
                } else {
                    if !artists.isEmpty {
                        Text("Исполнители").sectionTitle()
                        ForEach(artists) { artist in
                            NavigationLink {
                                ArtistView(artist: artist)
                            } label: {
                                HStack(spacing: 14) {
                                    Circle()
                                        .fill(RhythmTheme.surface2)
                                        .frame(width: 56, height: 56)
                                        .overlay(Image(systemName: "person.fill").foregroundStyle(RhythmTheme.secondary))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(artist.name)
                                            .font(.system(size: 16, weight: .semibold))
                                        if let genre = artist.genre {
                                            Text(genre)
                                                .font(.system(size: 12))
                                                .foregroundStyle(RhythmTheme.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(RhythmTheme.secondary)
                                }
                                .padding(10)
                                .rhythmGlass(18)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !tracks.isEmpty {
                        Text("Треки").sectionTitle().padding(.top, 5)
                        VerticalTracks(tracks: tracks)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onDisappear { task?.cancel() }
    }

    private func scheduleSearch() {
        task?.cancel()
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else {
            loading = false
            hasSearched = false
            tracks = []
            artists = []
            error = nil
            return
        }

        loading = true
        hasSearched = false
        error = nil
        task = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(value)
        }
    }

    private func performSearch() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return }
        task?.cancel()
        loading = true
        hasSearched = false
        task = Task { await search(value) }
    }

    private func search(_ value: String) async {
        do {
            let result = try await MusicCatalog.shared.search(value)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                tracks = result.tracks
                artists = result.artists
                loading = false
                hasSearched = true
                error = nil
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                loading = false
                hasSearched = true
                self.error = error.localizedDescription
            }
        }
    }
}

struct SearchField: View {
    @Binding var query: String
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RhythmTheme.secondary)

            TextField("Трек или исполнитель", text: $query)
                .submitLabel(.search)
                .onSubmit(submit)
                .foregroundStyle(Color.primary)

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RhythmTheme.secondary)
                }
            }
        }
        .padding(14)
        .rhythmGlass(18)
    }
}
