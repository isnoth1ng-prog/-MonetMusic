import SwiftUI
import SwiftData
import UIKit

struct PlayerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @Query private var libraryTracks: [LibraryTrack]
    
    @State private var showingLyrics = false
    
    private var currentTrack: Track? {
        audioPlayer.currentTrack
    }
    
    private var isLiked: Bool {
        guard let track = currentTrack else { return false }
        return libraryTracks.contains(where: { $0.id == track.id })
    }
    
    var body: some View {
        ZStack {
            // Ambient Background
            if let track = currentTrack {
                AsyncImage(url: track.highResCoverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.5))
                } placeholder: {
                    Color.monetBackground
                }
                .ignoresSafeArea()
            } else {
                Color.monetBackground.ignoresSafeArea()
            }
            
            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text("Сейчас играет")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                if let track = currentTrack {
                    // Cover Art
                    AsyncCoverImage(url: track.highResCoverURL, cornerRadius: 20, size: UIScreen.main.bounds.width - 64)
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.bottom, 40)
                    
                    // Track Info
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(track.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(track.artist)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer()
                        
                        Button(action: toggleLike) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 24))
                                .foregroundColor(isLiked ? MonetTheme.accent : .white)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 30)
                    
                    // Progress
                    VStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { audioPlayer.progress },
                            set: { newValue in audioPlayer.seek(to: newValue) }
                        ), in: 0...1)
                        .accentColor(.white)
                        
                        HStack {
                            Text(formatTime(seconds: audioPlayer.progress * audioPlayer.duration))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(formatTime(seconds: audioPlayer.duration))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    
                    // Controls
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
                                    .frame(width: 72, height: 72)
                                
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Button(action: { audioPlayer.playNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack {
                        Button(action: { showingLyrics.toggle() }) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 20))
                                .foregroundColor(showingLyrics ? MonetTheme.accent : .white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showingLyrics) {
            if let track = currentTrack {
                LyricsView(track: track)
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
