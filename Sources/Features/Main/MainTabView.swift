import SwiftUI

struct MainTabView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showingFullPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem { Label("Главная", systemImage: "house.fill") }

                MyWaveView()
                    .tabItem { Label("Волна", systemImage: "waveform") }

                SearchView()
                    .tabItem { Label("Поиск", systemImage: "magnifyingglass") }

                LibraryView()
                    .tabItem { Label("Медиатека", systemImage: "music.note.list") }

                SettingsView()
                    .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
            }
            .tint(MonetTheme.accent)

            if audioPlayer.currentTrack != nil {
                MiniPlayerView()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            showingFullPlayer = true
                        }
                    }
                    .padding(.bottom, 48)
            }

            if showingFullPlayer {
                PlayerView(isShowing: $showingFullPlayer)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
    }
}
