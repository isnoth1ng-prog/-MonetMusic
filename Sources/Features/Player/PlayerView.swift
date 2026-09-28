import SwiftUI
import SwiftData
import UIKit

struct PlayerView: View {
    @Binding var isShowing: Bool
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @Query private var libraryTracks: [LibraryTrack]
    
    @State private var showingLyrics = false
    @State private var coverImage: UIImage? = nil
    @State private var dragOffset = CGSize.zero
    
    @State private var lyrics: Lyrics?
    @State private var isLoadingLyrics = false
    private let musicService: MusicService = ITunesMusicService()
    
    private var currentTrack: Track? { audioPlayer.currentTrack }
    private var isLiked: Bool {
        guard let track = currentTrack else { return false }
        return libraryTracks.contains(where: { $0.id == track.id })
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.6))
                        .ignoresSafeArea()
                } else {
                    Color.monetBackground.ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
                    // Header / Drag handle
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)
                        
                        Text("Сейчас играет")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closePlayer()
                    }
                    
                    Spacer(minLength: 16)
                    
                    if let track = currentTrack {
                        if showingLyrics {
                            // Integrated Lyrics View
                            lyricsContentView()
                                .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.5)
                        } else {
                            // Cover Art
                            let coverSize = min(geo.size.width - 64, geo.size.height * 0.45)
                            AsyncImage(url: track.highResCoverURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .failure:
                                    ZStack {
                                        Color.monetSurface
                                        Image(systemName: "music.note").font(.system(size: 40)).foregroundColor(.monetSecondary)
                                    }
                                default:
                                    ZStack {
                                        Color.monetSurface
                                        ProgressView().tint(.white)
                                    }
                                }
                            }
                            .frame(width: coverSize, height: coverSize)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                        
                        Spacer(minLength: 24)
                        
                        // Track Info
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(track.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 16)
                            
                            Button(action: toggleLike) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 24))
                                    .foregroundColor(isLiked ? MonetTheme.accent : .white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Premium Slider
                        VStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { audioPlayer.progress },
                                set: { audioPlayer.seek(to: $0) }
                            ), in: 0...1)
                            .accentColor(.white)
                            .onAppear {
                                let thumbImage = UIImage(systemName: "circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                                UISlider.appearance().setThumbImage(thumbImage, for: .normal)
                            }
                            
                            HStack {
                                Text(formatTime(seconds: audioPlayer.progress * audioPlayer.duration))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("-" + formatTime(seconds: max(0, audioPlayer.duration - audioPlayer.progress * audioPlayer.duration)))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        
                        // Playback Controls
                        HStack(spacing: 40) {
                            Button(action: { audioPlayer.playPrevious() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: { audioPlayer.togglePlayPause() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 76, height: 76)
                                    
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.black)
                                        .offset(x: audioPlayer.isPlaying ? 0 : 3)
                                }
                            }
                            
                            Button(action: { audioPlayer.playNext() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 20)
                        
                        Spacer(minLength: 16)
                        
                        // Bottom row
                        HStack {
                            Button(action: toggleLyrics) {
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 22))
                                    .foregroundColor(showingLyrics ? .white : .white.opacity(0.4))
                                    .frame(width: 44, height: 44)
                                    .background(showingLyrics ? Color.white.opacity(0.2) : Color.clear)
                                    .clipShape(Circle())
                            }
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.4))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    if gesture.translation.height > 0 {
                        dragOffset = gesture.translation
                    }
                }
                .onEnded { gesture in
                    if gesture.translation.height > 100 {
                        closePlayer()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onChange(of: currentTrack?.id) { _ in
            loadCoverImage()
            if showingLyrics {
                fetchLyrics()
            }
        }
        .onAppear {
            loadCoverImage()
        }
    }
    
    @ViewBuilder
    private func lyricsContentView() -> some View {
        ZStack {
            if isLoadingLyrics {
                ProgressView().tint(.white)
            } else if let lyrics = lyrics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(lyrics.lines, id: \.self) { line in
                            Text(line.text)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                }
                // Gradient mask for smooth fading at top and bottom
                .mask(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black, .black, .black, .clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Текст песни не найден")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .transition(.opacity)
    }
    
    private func toggleLyrics() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingLyrics.toggle()
        }
        if showingLyrics && lyrics == nil {
            fetchLyrics()
        }
    }
    
    private func fetchLyrics() {
        guard let track = currentTrack else { return }
        isLoadingLyrics = true
        lyrics = nil
        Task {
            let fetched = try? await musicService.getLyrics(track: track)
            await MainActor.run {
                self.lyrics = fetched
                self.isLoadingLyrics = false
            }
        }
    }
    
    private func closePlayer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            isShowing = false
            dragOffset = .zero
        }
    }
    
    private func loadCoverImage() {
        guard let url = currentTrack?.highResCoverURL else {
            coverImage = nil
            return
        }
        Task {
            if let data = try? await URLSession.shared.data(from: url).0,
               let img = UIImage(data: data) {
                await MainActor.run { coverImage = img }
            }
        }
    }
    
    private func toggleLike() {
        guard let track = currentTrack else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let existing = libraryTracks.first(where: { $0.id == track.id }) {
            modelContext.delete(existing)
        } else {
            let libraryTrack = LibraryTrack(track: track)
            modelContext.insert(libraryTrack)
        }
        try? modelContext.save()
    }
    
    private func formatTime(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
