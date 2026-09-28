import SwiftUI
import SwiftData

struct MainTabView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showingFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem { Label("Главная", systemImage: "house.fill") }
                
                MyWaveView()
                    .tabItem { Label("Моя волна", systemImage: "play.circle.fill") }
                
                SearchView()
                    .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
                
                LibraryView()
                    .tabItem { Label("Медиатека", systemImage: "music.note.list") }
                
                SettingsView()
                    .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
            }
            .accentColor(MonetTheme.accent)
            
            if audioPlayer.currentTrack != nil {
                MiniPlayerView()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showingFullPlayer = true
                        }
                    }
                    .padding(.bottom, 50)
            }
            
            // Full Screen Player Overlay
            if showingFullPlayer {
                PlayerView(isShowing: $showingFullPlayer)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
    }
}
