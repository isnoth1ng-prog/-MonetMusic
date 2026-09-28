import SwiftUI
import SwiftData

struct MyWaveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryTracks: [LibraryTrack]
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    @State private var waveQueue: [Track] = []
    @State private var isLoading = false
    @State private var selectedMood: String = "Любое"
    @State private var animateGlow = false
    
    private let moods: [(name: String, icon: String, color: Color)] = [
        ("Любое", "sparkles", .indigo),
        ("Бодрое", "bolt.fill", .orange),
        ("Грустное", "cloud.rain.fill", .blue),
        ("Спокойное", "leaf.fill", .green),
        ("Для тренировки", "flame.fill", .red)
    ]
    
    private let musicService: MusicService = ITunesMusicService()
    
    var currentMoodColor: Color {
        moods.first(where: { $0.name == selectedMood })?.color ?? .indigo
    }
    
    var body: some View {
        ZStack {
            // Multi-layer gradient background
            Color.monetBackground.ignoresSafeArea()
            
            // Animated radial glow
            RadialGradient(
                gradient: Gradient(colors: [currentMoodColor.opacity(0.4), Color.clear]),
                center: .center,
                startRadius: 20,
                endRadius: animateGlow ? 350 : 250
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGlow)
            
            // Top ambient accent
            LinearGradient(
                gradient: Gradient(colors: [currentMoodColor.opacity(0.2), Color.clear]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo text
                Text("М О Я   В О Л Н А")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(6)
                    .padding(.bottom, 24)
                
                // Wave icon with glow ring
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(currentMoodColor.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                            .frame(width: CGFloat(160 + i * 40), height: CGFloat(160 + i * 40))
                            .scaleEffect(animateGlow ? 1.05 : 0.95)
                            .animation(
                                .easeInOut(duration: 2.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.3),
                                value: animateGlow
                            )
                    }
                    
                    // Main play button
                    Button(action: { startWave() }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: currentMoodColor.opacity(0.6), radius: 25, y: 8)
                            
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                                    .scaleEffect(1.3)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.black)
                                    .offset(x: 4)
                            }
                        }
                    }
                    .disabled(isLoading)
                }
                
                Spacer()
                
                // Mood selector
                VStack(spacing: 16) {
                    Text("Выберите настроение")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    HStack(spacing: 12) {
                        ForEach(moods, id: \.name) { mood in
                            Button(action: { withAnimation(.spring(response: 0.35)) { selectedMood = mood.name } }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedMood == mood.name ? mood.color : Color.white.opacity(0.08))
                                            .frame(width: 52, height: 52)
                                        
                                        Image(systemName: mood.icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedMood == mood.name ? .white : .white.opacity(0.5))
                                    }
                                    
                                    Text(mood.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(selectedMood == mood.name ? .white : .white.opacity(0.4))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            animateGlow = true
        }
    }
    
    private func startWave() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let baseTerms = ["русский рэп", "кальянный рэп", "русская попса", "хип хоп", "Скриптонит", "Баста", "Miyagi", "Oxxxymiron", "Макс Корж", "Нервы"]
                var queries = baseTerms
                
                switch selectedMood {
                case "Бодрое": queries = ["phonk", "dance русский", "клубная музыка", "энергичный рэп", "MORGENSHTERN"]
                case "Грустное": queries = ["грустный рэп", "лирика русская", "Lizer", "Хаски грустный", "Три дня дождя"]
                case "Спокойное": queries = ["lofi", "chill русский", "спокойная музыка", "Мот", "Jony"]
                case "Для тренировки": queries = ["phonk russian", "workout music", "hardbass", "Slava Marlow"]
                default: break
                }
                
                if !libraryTracks.isEmpty {
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
