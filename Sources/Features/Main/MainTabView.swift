import SwiftUI

struct MainTabView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @State private var showingFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Главная", systemImage: "house.fill")
                    }
                
                MyWaveView()
                    .tabItem {
                        Label("Моя волна", systemImage: "play.circle.fill")
                    }
                
                SearchView()
                    .tabItem {
                        Label("Поиск", systemImage: "magnifyingglass")
                    }
                
                LibraryView()
                    .tabItem {
                        Label("Медиатека", systemImage: "music.note.list")
                    }
            }
            .accentColor(MonetTheme.accent)
            
            if audioPlayer.currentTrack != nil {
                MiniPlayerView()
                    .onTapGesture {
                        showingFullPlayer.toggle()
                    }
                    .padding(.bottom, 50) // Adjust for tab bar height
            }
        }
        .sheet(isPresented: $showingFullPlayer) {
            PlayerView()
        }
        .preferredColorScheme(.dark)
    }
}
