import SwiftUI
import SwiftData
import UIKit

struct PlayerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @Query private var libraryTracks: [LibraryTrack]
    
    @State private var showingLyrics = false
    @State private var coverImage: UIImage? = nil
    
    private var currentTrack: Track? {
        audioPlayer.currentTrack
    }
    
    private var isLiked: Bool {
        guard let track = currentTrack else { return false }
        return libraryTracks.contains(where: { $0.id == track.id })
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — fixed size, clipped, never pushes layout
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 50)
                        .overlay(Color.black.opacity(0.55))
                        .ignoresSafeArea()
                } else {
                    Color.monetBackground.ignoresSafeArea()
                }
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        Spacer()
                        Text("Сейчас играет")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(1)
                        Spacer()
                        // Placeholder for symmetry
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 16)
                    
                    if let track = currentTrack {
                        let coverSize = min(geo.size.width - 64, geo.size.height * 0.38)
                        
                        // Cover Art — fixed square
                        AsyncImage(url: track.highResCoverURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                ZStack {
                                    Color.monetSurface
                                    Image(systemName: "music.note")
                                        .font(.system(size: 40))
                                        .foregroundColor(.monetSecondary)
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
                        
                        Spacer(minLength: 24)
                        
                        // Track Info
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: 17))
                                    .foregroundColor(.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 16)
                            
                            Button(action: toggleLike) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 22))
                                    .foregroundColor(isLiked ? MonetTheme.accent : .white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Progress Slider
                        VStack(spacing: 6) {
                            Slider(value: Binding(
                                get: { audioPlayer.progress },
                                set: { audioPlayer.seek(to: $0) }
                            ), in: 0...1)
                            .accentColor(.white)
                            
                            HStack {
                                Text(formatTime(seconds: audioPlayer.progress * audioPlayer.duration))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Text("-" + formatTime(seconds: max(0, audioPlayer.duration - audioPlayer.progress * audioPlayer.duration)))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        
                        // Playback Controls
                        HStack(spacing: 48) {
                            Button(action: { audioPlayer.playPrevious() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                            
                            Button(action: { audioPlayer.togglePlayPause() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 68, height: 68)
                                    
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.black)
                                        .offset(x: audioPlayer.isPlaying ? 0 : 2)
                                }
                            }
                            
                            Button(action: { audioPlayer.playNext() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.top, 24)
                        
                        Spacer(minLength: 16)
                        
                        // Bottom row — lyrics + queue
                        HStack {
                            Button(action: { showingLyrics.toggle() }) {
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 20))
                                    .foregroundColor(showingLyrics ? MonetTheme.accent : .white.opacity(0.5))
                                    .frame(width: 44, height: 44)
                            }
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onChange(of: currentTrack?.id) { _ in
            loadCoverImage()
        }
        .onAppear {
            loadCoverImage()
        }
        .sheet(isPresented: $showingLyrics) {
            if let track = currentTrack {
                LyricsView(track: track)
            }
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
