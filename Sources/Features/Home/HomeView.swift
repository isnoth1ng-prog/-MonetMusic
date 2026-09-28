import SwiftUI

struct HomeView: View {
    @State private var recentTracks: [Track] = []
    @State private var recommendedTracks: [Track] = []
    @State private var isGeneratingVibe = false
    
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
                        
                        // Моя Волна (My Vibe)
                        Button(action: startMyVibe) {
                            ZStack {
                                LinearGradient(colors: [Color(red: 0.1, green: 0.5, blue: 1.0), Color(red: 0.8, green: 0.2, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .cornerRadius(24)
                                    .shadow(color: Color(red: 0.8, green: 0.2, blue: 0.8).opacity(0.6), radius: 15, y: 10)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("МОЯ ВОЛНА")
                                            .font(.system(size: 26, weight: .black))
                                            .foregroundColor(.white)
                                        Text(isGeneratingVibe ? "Подбираем поток..." : "Бесконечная музыка под тебя")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    Spacer()
                                    if isGeneratingVibe {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 44))
                                            .foregroundColor(.white)
                                            .shadow(radius: 5)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 28)
                            }
                        }
                        .padding(.horizontal, MonetTheme.padding)
                        .disabled(isGeneratingVibe)
                        
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
            if let pop = try? await musicService.search(query: "русский рэп хиты") {
                await MainActor.run { self.recentTracks = pop }
            }
            if let fresh = try? await musicService.search(query: "новинки музыки русские") {
                await MainActor.run { self.recommendedTracks = fresh }
            }
        }
    }
    
    private func startMyVibe() {
        guard !isGeneratingVibe else { return }
        isGeneratingVibe = true
        
        Task {
            let artists = ["Miyagi", "Скриптонит", "Баста", "Oxxxymiron", "Macan", "Anna Asti", "LSP", "Kizaru", "Pharaoh", "Markul"]
            let randomArtist = artists.randomElement() ?? "Miyagi"
            
            if let tracks = try? await musicService.search(query: randomArtist) {
                let shuffled = tracks.shuffled()
                await MainActor.run {
                    self.isGeneratingVibe = false
                    if let first = shuffled.first {
                        audioPlayer.play(track: first, queue: shuffled)
                    }
                }
            } else {
                await MainActor.run { self.isGeneratingVibe = false }
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
