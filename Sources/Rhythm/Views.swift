import SwiftUI

struct RootView: View {
    @StateObject private var player = RhythmPlayer.shared
    @StateObject private var store = ListeningStore.shared
    @State private var selected = 0
    @State private var showPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selected) {
                NavigationStack { HomeView().navigationBarHidden(true) }
                    .tabItem { Label("Главная", systemImage: "house.fill") }.tag(0)
                NavigationStack { SearchView() }
                    .tabItem { Label("Поиск", systemImage: "magnifyingglass") }.tag(1)
                NavigationStack { FavoritesView() }
                    .tabItem { Label("Любимое", systemImage: "heart.fill") }.tag(2)
                NavigationStack { SettingsView() }
                    .tabItem { Label("Настройки", systemImage: "slider.horizontal.3") }.tag(3)
            }
            .tint(RhythmTheme.accent)

            if player.currentTrack != nil {
                MiniPlayerView {
                    showPlayer = true
                }
                .padding(.bottom, 49)
            }
        }
        .sheet(isPresented: $showPlayer) {
            FullPlayerView()
                .environmentObject(player)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .environmentObject(player)
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: ListeningStore
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(greeting).font(.system(size: 14, weight: .medium)).foregroundStyle(RhythmTheme.secondary)
                        Text("Rhythm").font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Circle()
                        .fill(RhythmTheme.accent.opacity(0.16))
                        .frame(width: 46, height: 46)
                        .overlay(Image(systemName: "waveform").foregroundStyle(RhythmTheme.accent))
                }

                NavigationLink {
                    WaveView(seed: nil)
                } label: {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Моя волна").font(.system(size: 25, weight: .bold, design: .rounded))
                                Text("Персональный поток без очереди")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.56))
                            }
                            Spacer()
                            Circle()
                                .fill(.white)
                                .frame(width: 52, height: 52)
                                .overlay(Image(systemName: "waveform").foregroundStyle(.black).font(.system(size: 21, weight: .bold)))
                        }
                        WaveShape()
                            .stroke(RhythmTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(height: 50)
                    }
                    .padding(22)
                    .rhythmGlass(28)
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
                        Text("Начни слушать").font(.system(size: 22, weight: .bold))
                        Text("Rhythm будет запоминать музыку и постепенно собирать твою волну.")
                            .foregroundStyle(RhythmTheme.secondary)
                    }
                    .padding(.vertical, 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .background(RhythmTheme.background)
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
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        for x in stride(from: 0, through: rect.width, by: 3) {
            let y = rect.midY + sin(x / rect.width * .pi * 4) * rect.height * 0.35
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

struct WaveView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @EnvironmentObject private var store: ListeningStore
    let seed: Track?
    @State private var loading = false
    @State private var started = false
    @State private var tracks: [Track] = []

    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(RhythmTheme.accent.opacity(0.12)).frame(width: 260, height: 260)
                    Circle().fill(.ultraThinMaterial).frame(width: 210, height: 210)
                    Circle().stroke(RhythmTheme.accent.opacity(0.55), lineWidth: 1).frame(width: 210, height: 210)
                    Image(systemName: "waveform").font(.system(size: 58, weight: .bold)).foregroundStyle(RhythmTheme.accent)
                }
                VStack(spacing: 9) {
                    Text(seed == nil ? "Моя волна" : "Моя волна по треку")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(seed == nil ? "Никакой очереди. Только следующий трек, который Rhythm выбрал для тебя." : "Поток, собранный вокруг «\(seed?.title ?? "")».")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RhythmTheme.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                Button {
                    start()
                } label: {
                    HStack(spacing: 10) {
                        if loading { ProgressView().tint(.black) }
                        else { Image(systemName: started ? "arrow.clockwise" : "play.fill") }
                        Text(started ? "Пересобрать волну" : "Слушать")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28).padding(.vertical, 16)
                    .background(.white, in: Capsule())
                }
                .disabled(loading)
                Spacer()
                if let current = player.currentTrack {
                    HStack(spacing: 12) {
                        CoverView(url: current.highResCoverURL, size: 50, radius: 13)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Сейчас играет").font(.system(size: 11, weight: .semibold)).foregroundStyle(RhythmTheme.secondary)
                            Text(current.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(current.artist).font(.system(size: 12)).foregroundStyle(RhythmTheme.secondary)
                        }
                        Spacer()
                        Button { player.toggle() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(.white)
                        }
                    }
                    .padding(12).rhythmGlass(18).padding(.horizontal, 18)
                }
                Spacer(minLength: 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("МОЯ ВОЛНА").font(.system(size: 12, weight: .bold)).tracking(2)
            }
        }
    }

    private func start() {
        loading = true
        Task {
            let result = await MusicCatalog.shared.wave(seed: seed, favorites: store.favorites, history: store.history)
            await MainActor.run {
                tracks = result
                loading = false
                started = true
                player.startWave(result)
            }
        }
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

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    EmptySearch(title: "Найди свою музыку", subtitle: "Треки, исполнители и дискография.")
                } else if loading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Ищу музыку…").font(.system(size: 13, weight: .medium)).foregroundStyle(RhythmTheme.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 80)
                } else if let error {
                    Text(error).foregroundStyle(RhythmTheme.secondary).frame(maxWidth: .infinity).padding(.top, 80)
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
                                    Circle().fill(RhythmTheme.surface2).frame(width: 56, height: 56)
                                        .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.5)))
                                    Text(artist.name).font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(.vertical, 5)
                            }.buttonStyle(.plain)
                        }
                    }
                    if !tracks.isEmpty {
                        Text("Треки").sectionTitle().padding(.top, 6)
                        VerticalTracks(tracks: tracks)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
        .background(RhythmTheme.background)
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
        .onDisappear { task?.cancel() }
    }

    private func scheduleSearch() {
        task?.cancel()
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count < 2 {
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
        error = nil
        task = Task {
            await search(value)
        }
    }

    private func search(_ value: String) async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return }
        task?.cancel()
        loading = true
        hasSearched = false
        error = nil
        task = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await MusicCatalog.shared.search(value)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    tracks = result.tracks
                    artists = result.artists
                    loading = false
                    hasSearched = true
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
}

struct SearchField: View {
    @Binding var query: String
    let submit: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(RhythmTheme.secondary)
            TextField("Трек или исполнитель", text: $query)
                .submitLabel(.search)
                .onSubmit(submit)
                .foregroundStyle(.white)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(RhythmTheme.secondary) }
            }
        }
        .padding(14).rhythmGlass(18)
    }
}

struct ArtistView: View {
    let artist: Artist
    @State private var tracks: [Track] = []
    @State private var loading = true
    @EnvironmentObject private var player: RhythmPlayer

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ZStack(alignment: .bottomLeading) {
                    if let imageURL = artist.imageURL {
                        AsyncImage(url: imageURL) { $0.resizable().scaledToFill() } placeholder: { Color.black }
                    } else {
                        LinearGradient(colors: [RhythmTheme.accent.opacity(0.45), RhythmTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                    LinearGradient(colors: [.clear, RhythmTheme.background], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(artist.name).font(.system(size: 34, weight: .bold, design: .rounded))
                        if let genre = artist.genre { Text(genre).font(.system(size: 14, weight: .medium)).foregroundStyle(RhythmTheme.secondary) }
                    }.padding(20)
                }
                .frame(height: 330)
                .clipped()

                HStack(spacing: 12) {
                    Button {
                        if let first = tracks.first { player.play(first, queue: tracks) }
                    } label: {
                        Label("Слушать", systemImage: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 22).padding(.vertical, 13)
                            .background(.white, in: Capsule())
                    }
                    NavigationLink {
                        WaveView(seed: tracks.first)
                    } label: {
                        Image(systemName: "waveform").frame(width: 46, height: 46).rhythmGlass(23)
                    }
                }.padding(.horizontal, 18)

                Text("Популярные треки").sectionTitle().padding(.horizontal, 18)
                if loading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(40)
                } else {
                    VerticalTracks(tracks: Array(tracks.prefix(20)))
                }

                Text("Дискография").sectionTitle().padding(.horizontal, 18).padding(.top, 8)
                let albums = Dictionary(grouping: tracks, by: { $0.album ?? "Синглы" })
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(albums.keys.sorted(), id: \.self) { album in
                            if let first = albums[album]?.first {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverView(url: first.highResCoverURL, size: 130, radius: 17)
                                    Text(album).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                }.frame(width: 130, alignment: .leading)
                            }
                        }
                    }.padding(.horizontal, 18)
                }
            }.padding(.bottom, 120)
        }
        .background(RhythmTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tracks = (try? await MusicCatalog.shared.artistTracks(id: artist.id)) ?? []
            loading = false
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var store: ListeningStore
    @EnvironmentObject private var player: RhythmPlayer

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
            .padding(.horizontal, 18).padding(.bottom, 120)
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

    private let accents = ["5A8CFF", "9B6BFF", "34C759", "FF9F0A", "FF375F", "64D2FF", "FFFFFF"]

    var body: some View {
        Form {
            Section("Внешний вид") {
                Picker("Тема", selection: $themeMode) {
                    Text("Тёмная").tag("dark")
                    Text("Системная").tag("system")
                    Text("Светлая").tag("light")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(accents, id: \.self) { hex in
                        Button {
                            accentHex = hex
                            setAccent(hex)
                        } label: {
                            Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(.white, lineWidth: accentHex == hex ? 2 : 0))
                        }
                    }
                }.padding(.vertical, 8)
                Text("Акцент меняет активные элементы, прогресс и свет интерфейса.")
                    .font(.system(size: 12)).foregroundStyle(RhythmTheme.secondary)
            }
            Section("Данные") {
                Button("Очистить историю", role: .destructive) { store.clearHistory() }
            }
            Section("Rhythm") {
                LabeledContent("Версия", value: "3.0")
                LabeledContent("Каталог", value: "iTunes Search")
                LabeledContent("Тексты", value: "LRCLIB")
            }
        }
        .scrollContentBackground(.hidden)
        .background(RhythmTheme.background)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.large)
    }

    private func setAccent(_ hex: String) {
        let rgb = Color.rgb(hex: hex)
        UserDefaults.standard.set(rgb.r, forKey: "accentR")
        UserDefaults.standard.set(rgb.g, forKey: "accentG")
        UserDefaults.standard.set(rgb.b, forKey: "accentB")
    }
}

struct MiniPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    let open: () -> Void
    var body: some View {
        HStack(spacing: 10) {
                CoverView(url: player.currentTrack?.highResCoverURL, size: 46, radius: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Text(player.currentTrack?.artist ?? "").font(.system(size: 12)).foregroundStyle(RhythmTheme.secondary).lineLimit(1)
                }
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").frame(width: 38, height: 38)
                }
            }
            .padding(8).padding(.trailing, 4).rhythmGlass(17)
        }
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .onTapGesture(perform: open)
        .padding(.horizontal, 10)
    }
}

struct FullPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AdaptivePlayerBackground(url: player.currentTrack?.highResCoverURL)
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "chevron.down").font(.system(size: 18, weight: .bold)) }
                    Spacer()
                    Text("СЕЙЧАС ИГРАЕТ").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Menu {
                        if let track = player.currentTrack {
                            NavigationLink("Моя волна по треку") { WaveView(seed: track) }
                        }
                        Button("Повтор") { player.cycleRepeat() }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 30, height: 30)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                if player.lyrics.isEmpty {
                    Spacer()
                    CoverView(url: player.currentTrack?.highResCoverURL, size: 260, radius: 28)
                    Spacer()
                } else {
                    LyricsFlowView(lines: player.lyrics, progress: player.progress)
                        .frame(maxHeight: 340)
                        .padding(.top, 18)
                    Spacer(minLength: 8)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentTrack?.title ?? "").font(.system(size: 24, weight: .bold, design: .rounded)).lineLimit(2)
                        Text(player.currentTrack?.artist ?? "").font(.system(size: 16)).foregroundStyle(.white.opacity(0.58))
                    }
                    Spacer()
                    Button { player.toggleLike() } label: {
                        Image(systemName: (player.currentTrack.map { player.isLiked($0) } ?? false) ? "heart.fill" : "heart")
                            .font(.system(size: 25, weight: .semibold))
                            .foregroundStyle((player.currentTrack.map { player.isLiked($0) } ?? false) ? RhythmTheme.accent : .white)
                    }
                }
                .padding(.horizontal, 22)

                Slider(value: Binding(get: { player.progress }, set: { player.seek($0) }), in: 0...max(player.duration, 1))
                    .tint(RhythmTheme.accent)
                    .padding(.horizontal, 18).padding(.top, 14)

                HStack {
                    Text(time(player.progress))
                    Spacer()
                    Text("-" + time(max(0, player.duration - player.progress)))
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.48))
                .padding(.horizontal, 20)

                HStack(spacing: 32) {
                    Button { player.shuffle.toggle() } label: {
                        Image(systemName: "shuffle").foregroundStyle(player.shuffle ? RhythmTheme.accent : .white.opacity(0.55))
                    }
                    Button { player.previous() } label: { Image(systemName: "backward.fill") }
                    Button { player.toggle() } label: {
                        Circle().fill(.white).frame(width: 70, height: 70)
                            .overlay(Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(.black).font(.system(size: 25, weight: .bold)))
                    }
                    Button { player.next() } label: { Image(systemName: "forward.fill") }
                    Button { player.cycleRepeat() } label: {
                        Image(systemName: player.repeatMode.icon).foregroundStyle(player.repeatMode == .off ? .white.opacity(0.55) : RhythmTheme.accent)
                    }
                }
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 18).padding(.bottom, 28)
            }
        }
        .foregroundStyle(.white)
    }

    private func time(_ value: Double) -> String {
        let seconds = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct LyricsFlowView: View {
    let lines: [LyricLine]
    let progress: Double

    private var activeIndex: Int {
        guard !lines.isEmpty else { return 0 }
        return max(0, lines.lastIndex(where: { $0.time <= progress }) ?? 0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.system(size: index == activeIndex ? 25 : 20, weight: index == activeIndex ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(index == activeIndex ? 1 : 0.30))
                            .scaleEffect(index == activeIndex ? 1.01 : 1)
                            .animation(.easeInOut(duration: 0.25), value: activeIndex)
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture { playerSeek(line.time) }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 90)
            }
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
            .onChange(of: activeIndex) { _, index in
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(lines[index].id, anchor: .center)
                }
            }
            .onAppear {
                if lines.indices.contains(activeIndex) { proxy.scrollTo(lines[activeIndex].id, anchor: .center) }
            }
        }
    }

    @EnvironmentObject private var player: RhythmPlayer
    private func playerSeek(_ value: Double) { player.seek(value) }
}

struct AdaptivePlayerBackground: View {
    let url: URL?
    var body: some View {
        ZStack {
            RhythmTheme.background
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill().blur(radius: 75).opacity(0.25)
                }
            }
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
        }.ignoresSafeArea()
    }
}

struct VerticalTracks: View {
    @EnvironmentObject private var player: RhythmPlayer
    let tracks: [Track]
    var body: some View {
        LazyVStack(spacing: 2) {
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
                            CoverView(url: track.highResCoverURL, size: 145, radius: 19)
                            Text(track.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            Text(track.artist).font(.system(size: 12)).foregroundStyle(RhythmTheme.secondary).lineLimit(1)
                        }.frame(width: 145, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 18)
        }
    }
}

struct TrackRow: View {
    @EnvironmentObject private var player: RhythmPlayer
    let track: Track
    var body: some View {
        HStack(spacing: 12) {
            Button { player.play(track) } label: {
                CoverView(url: track.highResCoverURL, size: 58, radius: 13)
            }
            .buttonStyle(.plain)

            Button { player.play(track) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(track.artist).font(.system(size: 13)).foregroundStyle(RhythmTheme.secondary).lineLimit(1)
                }
                Spacer()
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    player.toggleLike(track)
                } label: {
                    Label(player.isLiked(track) ? "Убрать из любимого" : "В любимое", systemImage: player.isLiked(track) ? "heart.slash" : "heart")
                }
                NavigationLink {
                    WaveView(seed: track)
                } label: {
                    Label("Моя волна по треку", systemImage: "waveform")
                }
                if let artistID = track.artistID {
                    NavigationLink {
                        ArtistView(artist: Artist(id: artistID, name: track.artist, genre: track.genre, imageURL: track.highResCoverURL))
                    } label: {
                        Label("Исполнитель", systemImage: "person")
                    }
                }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.45)).frame(width: 32, height: 40)
            }
        }
        .padding(.vertical, 7)
    }
}

struct SectionHeader: View {
    let title: String
    let action: String
    let actionBlock: () -> Void
    var body: some View {
        HStack {
            Text(title).font(.system(size: 21, weight: .bold, design: .rounded))
            Spacer()
            Button(action: actionBlock) { Text(action).font(.system(size: 13, weight: .semibold)).foregroundStyle(RhythmTheme.accent) }
        }
    }
}

struct EmptySearch: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 38)).foregroundStyle(.white.opacity(0.18))
            Text(title).font(.system(size: 20, weight: .semibold))
            Text(subtitle).font(.system(size: 14)).foregroundStyle(RhythmTheme.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 100)
    }
}

extension Text {
    func sectionTitle() -> some View {
        self.font(.system(size: 21, weight: .bold, design: .rounded))
    }
}

extension Color {
    init(hex: String) {
        let value = Int(hex, radix: 16) ?? 0x5A8CFF
        self.init(
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255
        )
    }

    static func rgb(hex: String) -> (r: Double, g: Double, b: Double) {
        let value = Int(hex, radix: 16) ?? 0x5A8CFF
        return (Double((value >> 16) & 255) / 255, Double((value >> 8) & 255) / 255, Double(value & 255) / 255)
    }
}
