import SwiftUI

struct HomeView: View {
    @State private var recentTracks: [Track] = []
    @State private var recommendedTracks: [Track] = []
    
    private let musicService: MusicService = ITunesMusicService()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<24: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // Generative ambient background based on time of day
                LinearGradient(
                    gradient: Gradient(colors: [MonetTheme.accent.opacity(0.3), Color.monetBackground, Color.monetBackground]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        Text(greeting)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, MonetTheme.padding)
                            .padding(.top, 20)
                        
                        // Example section: Trending (Fetched from a preset query)
                        SectionView(title: "В тренде", tracks: recentTracks, isLarge: true) { track in
                            audioPlayer.play(track: track, queue: recentTracks)
                        }
                        
                        SectionView(title: "Свежие релизы", tracks: recommendedTracks, isLarge: false) { track in
                            audioPlayer.play(track: track, queue: recommendedTracks)
                        }
                        
                        Spacer(minLength: 120)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadInitialData()
            }
        }
    }
    
    private func loadInitialData() {
        guard recentTracks.isEmpty else { return }
        
        Task {
            if let pop = try? await musicService.search(query: "Top hits") {
                await MainActor.run { self.recentTracks = pop }
            }
            if let fresh = try? await musicService.search(query: "New release") {
                await MainActor.run { self.recommendedTracks = fresh }
            }
        }
    }
}

struct SectionView: View {
    let title: String
    let tracks: [Track]
    var isLarge: Bool = false
    let onPlay: (Track) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, MonetTheme.padding)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(tracks) { track in
                        Button(action: { onPlay(track) }) {
                            VStack(alignment: .leading, spacing: 10) {
                                AsyncCoverImage(url: track.coverURL, size: isLarge ? 200 : 140)
                                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                                
                                Text(track.title)
                                    .font(.system(size: isLarge ? 16 : 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: isLarge ? 14 : 12))
                                    .foregroundColor(.monetSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: isLarge ? 200 : 140)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, MonetTheme.padding)
                .padding(.bottom, 10)
            }
        }
    }
}
