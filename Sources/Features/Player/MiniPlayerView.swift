import SwiftUI

struct MiniPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayerService.shared
    
    var body: some View {
        if let track = audioPlayer.currentTrack {
            VStack(spacing: 0) {
                // Progress Bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.monetSecondary.opacity(0.3))
                        .overlay(
                            Rectangle()
                                .fill(MonetTheme.accent)
                                .frame(width: geometry.size.width * CGFloat(audioPlayer.progress), alignment: .leading),
                            alignment: .leading
                        )
                }
                .frame(height: 2)
                
                HStack(spacing: 12) {
                    AsyncCoverImage(url: track.coverURL, cornerRadius: 6, size: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundColor(.monetSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Button(action: {
                        audioPlayer.playNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Color.monetSurface.opacity(0.85)
                        .glassmorphism()
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
    }
}
