import SwiftUI
import SwiftData

struct MyWaveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    @State private var waveQueue: [Track] = []
    @State private var isLoading = false
    @State private var selectedMood: String = "Любое"
    
    private let moods = ["Любое", "Бодрое", "Грустное", "Спокойное", "Для тренировки"]
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
                
                Text("Настроение: \(selectedMood)")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(moods, id: \.self) { mood in
                            Button(action: { selectedMood = mood }) {
                                Text(mood)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedMood == mood ? Color.white : Color.white.opacity(0.1))
                                    .foregroundColor(selectedMood == mood ? .black : .white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
        }
    }
    
    private func startWave() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let baseTerms = ["русский рэп", "кальянный рэп", "русская попса", "хип хоп", "Скриптонит", "Баста", "Miyagi"]
                var queries = baseTerms
                
                switch selectedMood {
                case "Бодрое": queries = ["phonk", "dance", "клубная музыка", "энергичный рэп"]
                case "Грустное": queries = ["грустный рэп", "лирика", "sad", "меланхолия"]
                case "Спокойное": queries = ["lofi", "chill", "спокойная музыка", "acoustic"]
                case "Для тренировки": queries = ["phonk", "workout", "hardbass", "rock"]
                default: break
                }
                
                if !libraryTracks.isEmpty {
                    // Add favorite artists to query pool
                    let artists = Set(libraryTracks.map { $0.artist })
                    queries.append(contentsOf: artists)
                }
                
                let randomQuery = queries.randomElement() ?? "русский рэп"
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
