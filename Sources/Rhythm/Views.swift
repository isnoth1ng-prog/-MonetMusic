import SwiftUI

struct RootView: View {
    @StateObject private var player = RhythmPlayer.shared
    @StateObject private var store = ListeningStore.shared
    @StateObject private var appearance = RhythmAppearance.shared
    @AppStorage("themeMode") private var themeMode = "dark"
    @State private var selected = 0
    @State private var showPlayer = false

    private let tabs: [(String, String)] = [
        ("Главная", "house"),
        ("Поиск", "magnifyingglass"),
        ("Любимое", "heart"),
        ("Настройки", "slider.horizontal.3")
    ]

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack { HomeView() }
                .toolbar(.hidden, for: .navigationBar)
                .tag(0)

            NavigationStack { SearchView() }
                .tag(1)

            NavigationStack { FavoritesView() }
                .tag(2)

            NavigationStack { SettingsView() }
                .tag(3)
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(RhythmTheme.accent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 7) {
                if player.currentTrack != nil {
                    MiniPlayerView { showPlayer = true }
                }

                                    HStack(spacing: 4) {
                        ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                            Button {
                                selected = index
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: selected == index ? tab.1 + ".fill" : tab.1)
                                        .font(.system(size: 17, weight: .semibold))
                                    Text(tab.0)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(selected == index ? Color.primary : RhythmTheme.secondary)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .rhythmGlass(18)
                        }
                    }
                    .padding(6)
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            FullPlayerView()
                .environmentObject(player)
        }
        .environmentObject(player)
        .environmentObject(store)
        .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil)
        .onChange(of: appearance.revision) { _, _ in }
    }
}

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

struct ArtistView: View {
    let artist: Artist
    @State private var tracks: [Track] = []
    @State private var albums: [Album] = []
    @State private var loading = true
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                artistHeader

                HStack(spacing: 10) {
                    Button {
                        if let first = tracks.first {
                            player.play(first, queue: tracks)
                        }
                    } label: {
                        Label("Слушать", systemImage: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                            .background(Color.primary, in: Capsule())
                    }

                    NavigationLink {
                        WaveView(seed: tracks.first)
                    } label: {
                        Image(systemName: "waveform")
                            .frame(width: 48, height: 48)
                            .rhythmGlass(24)
                    }
                }

                Text("Популярные треки").sectionTitle()
                if loading {
                    ProgressView().tint(RhythmTheme.accent).frame(maxWidth: .infinity).padding(45)
                } else {
                    VerticalTracks(tracks: Array(tracks.prefix(20)))
                }

                if !albums.isEmpty {
                    Text("Дискография").sectionTitle().padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(albums) { album in
                                NavigationLink {
                                    AlbumView(album: album)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        CoverView(url: album.coverURL, size: 142, radius: 20)
                                        Text(album.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .lineLimit(2)
                                        Text("\(album.type.rawValue) · \(album.trackCount) треков")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(RhythmTheme.secondary)
                                    }
                                    .frame(width: 142, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
            }
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let loadedTracks = MusicCatalog.shared.artistTracks(id: artist.id)
            async let loadedAlbums = MusicCatalog.shared.artistAlbums(id: artist.id)
            tracks = (try? await loadedTracks) ?? []
            albums = (try? await loadedAlbums) ?? []
            loading = false
        }
    }

    private var artistHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let imageURL = artist.imageURL ?? tracks.first?.highResCoverURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RhythmTheme.surface
                }
            } else {
                RhythmTheme.surface
            }

            LinearGradient(
                colors: [.clear, RhythmTheme.background.opacity(0.96)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("ИСПОЛНИТЕЛЬ")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(RhythmTheme.accent)
                Text(artist.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-1)
                if let genre = artist.genre {
                    Text(genre)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RhythmTheme.secondary)
                }
            }
            .padding(20)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }
}

struct AlbumView: View {
    let album: Album
    @State private var tracks: [Track] = []
    @State private var loading = true
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    CoverView(url: album.coverURL, size: 160, radius: 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(album.type.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(RhythmTheme.accent)
                        Text(album.title)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .lineLimit(4)
                        Text(album.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(RhythmTheme.secondary)
                        if let date = album.releaseDate {
                            Text(date.formatted(.dateTime.year()))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Button {
                    guard let first = tracks.first else { return }
                    player.play(first, queue: tracks)
                } label: {
                    Label("Слушать релиз", systemImage: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.primary, in: Capsule())
                }

                Text("(tracks.count) треков").sectionTitle()

                if loading {
                    ProgressView().tint(RhythmTheme.accent).frame(maxWidth: .infinity).padding(50)
                } else {
                    VerticalTracks(tracks: tracks)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tracks = (try? await MusicCatalog.shared.albumTracks(id: album.id)) ?? []
            loading = false
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: ListeningStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if store.favorites.isEmpty {
                    EmptySearch(title: "Любимое пока пусто", subtitle: "Нажимай сердечко на треках, которые хочешь сохранить.")
                } else {
                    Text("Треки").sectionTitle()
                    VerticalTracks(tracks: store.favorites)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Любимое")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct SettingsView: View {
    @AppStorage("themeMode") private var themeMode = "dark"
    @AppStorage("accentHex") private var accentHex = "5A8CFF"
    @EnvironmentObject private var store: ListeningStore
    @StateObject private var appearance = RhythmAppearance.shared
    @StateObject private var appleMusic = AppleMusicService.shared

    private let accents = [
        "5A8CFF", "9B6BFF", "34C759", "FF9F0A",
        "FF375F", "64D2FF", "FFFFFF"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                settingsSection("Внешний вид") {
                    Text("Тема")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RhythmTheme.secondary)

                    HStack(spacing: 8) {
                        ThemeChoice(title: "Тёмная", icon: "moon.fill", selected: themeMode == "dark") {
                            themeMode = "dark"
                            appearance.applyTheme("dark")
                        }
                        ThemeChoice(title: "Система", icon: "circle.lefthalf.filled", selected: themeMode == "system") {
                            themeMode = "system"
                            appearance.applyTheme("system")
                        }
                        ThemeChoice(title: "Светлая", icon: "sun.max.fill", selected: themeMode == "light") {
                            themeMode = "light"
                            appearance.applyTheme("light")
                        }
                    }

                    Text("Акцент")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RhythmTheme.secondary)
                        .padding(.top, 5)

                    HStack(spacing: 13) {
                        ForEach(accents, id: \.self) { hex in
                            Button {
                                accentHex = hex
                                appearance.applyAccent(hex)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 31, height: 31)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: accentHex == hex ? 2.2 : 0)
                                            .padding(-3)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                settingsSection("Музыка") {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .rhythmGlass(21)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Music")
                                .font(.system(size: 15, weight: .semibold))
                            Text(appleMusic.authorization == .authorized ? "Доступ разрешён" : "Нужен доступ для полного стриминга")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                        }

                        Spacer()

                        if appleMusic.authorization != .authorized {
                            Button("Подключить") {
                                Task { _ = await appleMusic.requestAuthorization() }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RhythmTheme.accent)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(RhythmTheme.accent)
                        }
                    }
                }

                settingsSection("Данные") {
                    Button("Очистить историю", role: .destructive) {
                        store.clearHistory()
                    }
                }

                settingsSection("Rhythm") {
                    LabeledContent("Версия", value: "4.0")
                    LabeledContent("Каталог", value: "Apple Music + каталог метаданных")
                    LabeledContent("Тексты", value: "LRCLIB")
                    LabeledContent("Wave", value: "Адаптивная, трек за треком")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(RhythmTheme.secondary)

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .rhythmGlass(24)
        }
    }
}

struct ThemeChoice: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? RhythmTheme.accent : Color.primary)
            .background(selected ? RhythmTheme.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

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

struct FullPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false

    var body: some View {
        ZStack {
            AdaptivePlayerBackground(url: player.currentTrack?.highResCoverURL)

            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: 40, height: 40)
                                    .rhythmGlass(20)
                            }

                            Spacer()

                            VStack(spacing: 3) {
                                Text("СЕЙЧАС ИГРАЕТ")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(2.1)
                                    .foregroundStyle(RhythmTheme.secondary)
                                if player.usingAppleMusic {
                                    Text("APPLE MUSIC")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundStyle(RhythmTheme.accent)
                                }
                            }

                            Spacer()

                            Menu {
                                if let track = player.currentTrack {
                                    NavigationLink("Моя волна по треку") {
                                        WaveView(seed: track)
                                    }
                                }
                                Button("Режим повтора") { player.cycleRepeat() }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 40, height: 40)
                                    .rhythmGlass(20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        Button {
                            showLyrics = true
                        } label: {
                            ZStack {
                                CoverView(
                                    url: player.currentTrack?.highResCoverURL,
                                    size: min(proxy.size.width - 42, 365),
                                    radius: 30
                                )

                                if !player.lyrics.isEmpty {
                                    Image(systemName: "quote.opening")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .frame(width: 52, height: 52)
                                        .rhythmGlass(28)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)

                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(player.currentTrack?.title ?? "")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .tracking(-0.6)
                                    .lineLimit(2)
                                Text(player.currentTrack?.artist ?? "")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(RhythmTheme.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button { player.toggleLike() } label: {
                                Image(systemName: (player.currentTrack.map { player.isLiked($0) } ?? false) ? "heart.fill" : "heart")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle((player.currentTrack.map { player.isLiked($0) } ?? false) ? RhythmTheme.accent : Color.primary)
                                    .frame(width: 46, height: 46)
                                    .rhythmGlass(23)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 24)

                        Slider(
                            value: Binding(get: { player.progress }, set: { player.seek($0) }),
                            in: 0...max(player.duration, 1)
                        )
                        .tint(RhythmTheme.accent)
                        .padding(.horizontal, 19)
                        .padding(.top, 15)

                        HStack {
                            Text(time(player.progress))
                            Spacer()
                            Text("-" + time(max(0, player.duration - player.progress)))
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(RhythmTheme.secondary)
                        .padding(.horizontal, 22)

                        HStack(spacing: 34) {
                            Button { player.shuffle.toggle() } label: {
                                Image(systemName: "shuffle")
                                    .foregroundStyle(player.shuffle ? RhythmTheme.accent : RhythmTheme.secondary)
                            }
                            Button { player.previous() } label: {
                                Image(systemName: "backward.fill")
                            }
                            Button { player.toggle() } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundStyle(RhythmTheme.background)
                                    .frame(width: 74, height: 74)
                                    .background(Color.primary, in: Circle())
                            }
                            Button { player.next() } label: {
                                Image(systemName: "forward.fill")
                            }
                            Button { player.cycleRepeat() } label: {
                                Image(systemName: player.repeatMode.icon)
                                    .foregroundStyle(player.repeatMode == .off ? RhythmTheme.secondary : RhythmTheme.accent)
                            }
                        }
                        .font(.system(size: 19, weight: .semibold))
                        .padding(.top, 23)

                        Button { showLyrics = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "quote.bubble")
                                Text(player.lyrics.isEmpty ? "Текст недоступен" : "Показать текст")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(player.lyrics.isEmpty ? RhythmTheme.secondary : Color.primary)
                            .padding(15)
                            .rhythmGlass(18)
                        }
                        .disabled(player.lyrics.isEmpty)
                        .padding(.horizontal, 18)
                        .padding(.top, 22)

                        if let error = player.streamError {
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(RhythmTheme.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                        }

                        Spacer(minLength: 30)
                    }
                }
            }
        }
        .foregroundStyle(Color.primary)
        .sheet(isPresented: $showLyrics) {
            LyricsSheet().environmentObject(player)
        }
    }

    private func time(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct LyricsSheet: View {
    @EnvironmentObject private var player: RhythmPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ТЕКСТ")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2.2)
                            .foregroundStyle(RhythmTheme.secondary)
                        Text(player.currentTrack?.title ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .frame(width: 36, height: 36)
                            .rhythmGlass(18)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                LyricsFlowView(lines: player.lyrics, progress: player.progress)
            }
        }
    }
}

struct LyricsFlowView: View {
    let lines: [LyricLine]
    let progress: Double
    @EnvironmentObject private var player: RhythmPlayer

    private var activeIndex: Int {
        guard !lines.isEmpty else { return 0 }
        return max(0, lines.lastIndex(where: { $0.time <= progress }) ?? 0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 19) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.system(
                                size: index == activeIndex ? 27 : 20,
                                weight: index == activeIndex ? .bold : .semibold,
                                design: .rounded
                            ))
                            .foregroundStyle(Color.primary.opacity(index == activeIndex ? 1 : 0.30))
                            .scaleEffect(index == activeIndex ? 1.01 : 1)
                            .animation(.easeInOut(duration: 0.25), value: activeIndex)
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture { player.seek(line.time) }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 100)
            }
            .mask(
                LinearGradient(
                    colors: [.clear, .black, .black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: activeIndex) { _, index in
                guard lines.indices.contains(index) else { return }
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(lines[index].id, anchor: .center)
                }
            }
            .onAppear {
                guard lines.indices.contains(activeIndex) else { return }
                proxy.scrollTo(lines[activeIndex].id, anchor: .center)
            }
        }
    }
}

struct AdaptivePlayerBackground: View {
    let url: URL?

    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable()
                        .scaledToFill()
                        .blur(radius: 70)
                        .opacity(0.30)
                }
            }

            LinearGradient(
                colors: [RhythmTheme.background.opacity(0.12), RhythmTheme.background.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

struct VerticalTracks: View {
    let tracks: [Track]

    var body: some View {
        LazyVStack(spacing: 3) {
            ForEach(tracks) { track in
                TrackRow(track: track)
            }
        }
    }
}

struct HorizontalTracks: View {
    @EnvironmentObject private var player: RhythmPlayer
    let tracks: [Track]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(tracks) { track in
                    Button { player.play(track, queue: tracks) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            CoverView(url: track.highResCoverURL, size: 145, radius: 20)
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(RhythmTheme.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 145, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }
}

struct TrackRow: View {
    @EnvironmentObject private var player: RhythmPlayer
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            Button { player.play(track) } label: {
                CoverView(url: track.highResCoverURL, size: 58, radius: 15)
            }
            .buttonStyle(.plain)

            Button { player.play(track) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        if track.isExplicit {
                            Text("E")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RhythmTheme.secondary.opacity(0.16), in: Capsule())
                        }
                    }
                    Text(track.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RhythmTheme.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    player.toggleLike(track)
                } label: {
                    Label(
                        player.isLiked(track) ? "Убрать из любимого" : "В любимое",
                        systemImage: player.isLiked(track) ? "heart.slash" : "heart"
                    )
                }

                NavigationLink {
                    WaveView(seed: track)
                } label: {
                    Label("Моя волна по треку", systemImage: "waveform")
                }

                if let artistID = track.artistID {
                    NavigationLink {
                        ArtistView(
                            artist: Artist(
                                id: artistID,
                                name: track.artist,
                                genre: track.genre,
                                imageURL: track.highResCoverURL
                            )
                        )
                    } label: {
                        Label("Исполнитель", systemImage: "person")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(RhythmTheme.secondary)
                    .frame(width: 32, height: 40)
            }
        }
        .padding(.vertical, 7)
    }
}

struct EmptySearch: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 36))
                .foregroundStyle(RhythmTheme.accent.opacity(0.65))
            Text(title)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RhythmTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

extension Text {
    func sectionTitle() -> some View {
        self.font(.system(size: 21, weight: .bold, design: .rounded))
    }
}
