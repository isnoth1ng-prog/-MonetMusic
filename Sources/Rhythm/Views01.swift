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

            NavigationStack { ConfigScreen() }
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
            FixedFullPlayerView()
                .environmentObject(player)
        }
        .environmentObject(player)
        .environmentObject(store)
        .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil)
        .onChange(of: appearance.revision) { _, _ in }
    }
}

