import SwiftUI
import SwiftData

struct MyWaveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    @State private var waveQueue: [Track] = []
    @State private var isLoading = false
    private let musicService: MusicService = ITunesMusicService()
    
    var body: some View {
        ZStack {
            // Generative-like animated background
            LinearGradient(
                gradient: Gradient(colors: [Color.indigo.opacity(0.4), Color.monetBackground]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Play Button for Wave
                Button(action: {
                    startWave()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 120, height: 120)
                            .shadow(color: .indigo.opacity(0.5), radius: 30, x: 0, y: 10)
                        
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.black)
                                .offset(x: 4) // visual center adjust
                        }
                    }
                }
                .disabled(isLoading)
                
                Spacer()
                
                Text("Моя волна")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.white)
                
                Text("Музыка, подобранная для вас")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
                
                Spacer()
            }
        }
    }
    
    private func startWave() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                // Mix favorite artists with some random discovery terms
                let seedTerms = ["pop", "rock", "indie", "electronic", "chill"]
                var queries = seedTerms
                
                if !libraryTracks.isEmpty {
                    // Add favorite artists to query pool
                    let artists = Set(libraryTracks.map { $0.artist })
                    queries.append(contentsOf: artists)
                }
                
                let randomQuery = queries.randomElement() ?? "pop"
                let tracks = try await musicService.search(query: randomQuery)
                
                let shuffled = tracks.shuffled()
                
                await MainActor.run {
                    self.waveQueue = shuffled
                    self.isLoading = false
                    if let first = shuffled.first {
                        audioPlayer.play(track: first, queue: shuffled)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
