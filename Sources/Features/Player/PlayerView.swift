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
    @AppStorage("lyricsFontSize") private var lyricsFontSize: Double = 24.0
    
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
                // 1. Solid base to prevent any transparency showing the tab view
                Color.black.ignoresSafeArea()
                
                // 2. Blurred cover art background
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 80)
                        .overlay(Color.black.opacity(0.5))
                        .ignoresSafeArea()
                } else {
                    Color.monetBackground.ignoresSafeArea()
                }
                
                // Content
                VStack(spacing: 0) {
                    // Header / Drag handle
                    VStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 36, height: 5)
                            .padding(.top, 12)
                        
                        Text("Сейчас играет")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1.5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        closePlayer()
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if gesture.translation.height > 0 {
                                    dragOffset = gesture.translation
                                }
                            }
                            .onEnded { gesture in
                                if gesture.translation.height > 80 {
                                    closePlayer()
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    
                    Spacer(minLength: 16)
                    
                    if let track = currentTrack {
                        if showingLyrics {
                            // Integrated Karaoke Lyrics View
                            lyricsContentView()
                                .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.55)
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
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.4), radius: 25, y: 15)
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
                        
                        // Custom Interactive Slider
                        CustomSlider(
                            progress: Binding(
                                get: { audioPlayer.progress },
                                set: { audioPlayer.seek(to: $0) }
                            ),
                            duration: audioPlayer.duration
                        )
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        
                        // Playback Controls
                        HStack(spacing: 45) {
                            Button(action: { audioPlayer.playPrevious() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 36))
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
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 20)
                        
                        Spacer(minLength: 16)
                        
                        // Bottom row
                        HStack(spacing: 24) {
                            Button(action: toggleLyrics) {
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 20, weight: showingLyrics ? .bold : .regular))
                                    .foregroundColor(showingLyrics ? .black : .white.opacity(0.6))
                                    .frame(width: 48, height: 48)
                                    .background(showingLyrics ? Color.white : Color.clear)
                                    .clipShape(Circle())
                            }
                            
                            if showingLyrics {
                                Button(action: cycleFontSize) {
                                    Image(systemName: "textformat.size")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.8))
                                        .frame(width: 40, height: 40)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .transition(.opacity)
                            }
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 48, height: 48)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
        }
        .offset(y: dragOffset.height)
        .onChange(of: currentTrack?.id) { oldId, newId in
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
                let currentTime = audioPlayer.progress * audioPlayer.duration
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { item in
                                let index = item.offset
                                let line = item.element
                                let isActive = isLineActive(index: index, currentTime: currentTime, lines: lyrics.lines)
                                
                                Text(line.text)
                                    .font(.system(size: isActive ? CGFloat(lyricsFontSize + 4) : CGFloat(lyricsFontSize), weight: .bold))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .scaleEffect(isActive ? 1.05 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
                                    .id(index)
                                    .onTapGesture {
                                        if lyrics.isSynced, let timeStart = line.timeStart {
                                            let percentage = timeStart / audioPlayer.duration
                                            audioPlayer.seek(to: percentage)
                                        }
                                    }
                            }
                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 40)
                    }
                    .onChange(of: currentTime) { oldTime, newTime in
                        if lyrics.isSynced {
                            let newIndex = getActiveLineIndex(currentTime: newTime, lines: lyrics.lines)
                            let oldIndex = getActiveLineIndex(currentTime: oldTime, lines: lyrics.lines)
                            
                            // Only auto-scroll when the line actually changes!
                            if newIndex != oldIndex, let activeIndex = newIndex {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(activeIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
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
    
    private func isLineActive(index: Int, currentTime: Double, lines: [LyricsLine]) -> Bool {
        guard let lineTime = lines[index].timeStart else { return false }
        let nextLineTime = index + 1 < lines.count ? (lines[index + 1].timeStart ?? Double.infinity) : Double.infinity
        return currentTime >= lineTime && currentTime < nextLineTime
    }
    
    private func getActiveLineIndex(currentTime: Double, lines: [LyricsLine]) -> Int? {
        for i in 0..<lines.count {
            if isLineActive(index: i, currentTime: currentTime, lines: lines) {
                return i
            }
        }
        return nil
    }
    
    private func toggleLyrics() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingLyrics.toggle()
        }
        if showingLyrics && lyrics == nil {
            fetchLyrics()
        }
    }
    
    private func cycleFontSize() {
        let sizes: [Double] = [16.0, 20.0, 24.0, 28.0, 32.0]
        if let current = sizes.firstIndex(of: lyricsFontSize) {
            lyricsFontSize = sizes[(current + 1) % sizes.count]
        } else {
            lyricsFontSize = 24.0
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
}

// MARK: - Custom Slider
struct CustomSlider: View {
    @Binding var progress: Double
    let duration: Double
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var currentProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: isDragging ? 8 : 4)
                    
                    // Fill track
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(currentProgress)), height: isDragging ? 8 : 4)
                    
                    // Thumb
                    if isDragging {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .offset(x: max(0, min(geo.size.width - 16, geo.size.width * CGFloat(currentProgress) - 8)))
                            .shadow(radius: 4)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isDragging)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            dragProgress = Double(p)
                        }
                        .onEnded { value in
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            progress = Double(p)
                            isDragging = false
                        }
                )
            }
            .frame(height: 16)
            
            // Time Labels
            HStack {
                Text(formatTime(seconds: currentProgress * duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("-" + formatTime(seconds: max(0, duration - currentProgress * duration)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private func formatTime(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
