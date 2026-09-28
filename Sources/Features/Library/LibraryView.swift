import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \\LibraryTrack.addedAt, order: .reverse) private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var selectedSection = "Избранное"
    @State private var history: [Track] = []

    private let sections = ["Избранное", "История", "Артисты"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.monetBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("Раздел", selection: $selectedSection) {
                            ForEach(sections, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, MonetTheme.padding)
                        .padding(.top, 10)

                        switch selectedSection {
                        case "История":
                            historyView
                        case "Артисты":
                            artistsView
                        default:
                            favoritesView
                        }

                        Spacer(minLength: 110)
                    }
                }
            }
            .navigationTitle("Медиатека")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                history = ListeningHistory.shared.recentTracks(limit: 50)
            }
        }
    }

    @ViewBuilder
    private var favoritesView: some View {
        if libraryTracks.isEmpty {
            emptyState(
                icon: "heart",
                title: "Пока ничего нет",
                subtitle: "Нажми сердечко в плеере — трек попадёт в медиатеку."
            )
        } else {
            LazyVStack(spacing: 2) {
                ForEach(libraryTracks) { item in
                    TrackRowView(track: item.track) {
                        audioPlayer.play(track: item.track, queue: libraryTracks.map(\.track))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historyView: some View {
        if history.isEmpty {
            emptyState(
                icon: "clock",
                title: "История пуста",
                subtitle: "Включи пару треков — Rhythm начнёт запоминать твой вкус."
            )
        } else {
            LazyVStack(spacing: 2) {
                ForEach(history) { track in
                    TrackRowView(track: track) {
                        audioPlayer.play(track: track, queue: history)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var artistsView: some View {
        let artists = Dictionary(grouping: libraryTracks.map(\.track), by: \.artist)
            .map { (artist: $0.key, track: $0.value.first) }
            .sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }

        if artists.isEmpty {
            emptyState(
                icon: "person.2",
                title: "Артисты появятся здесь",
                subtitle: "Добавь несколько любимых треков."
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(artists, id: \.artist) { item in
                    HStack(spacing: 14) {
                        AsyncCoverImage(url: item.track?.highResCoverURL, cornerRadius: 28, size: 56)
                        Text(item.artist)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(libraryTracks.filter { $0.artist == item.artist }.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.monetSecondary)
                    }
                    .padding(.horizontal, MonetTheme.padding)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38))
                .foregroundColor(.monetSecondary.opacity(0.55))
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.monetSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }
}
