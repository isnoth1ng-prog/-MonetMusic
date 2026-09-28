import SwiftUI

struct LyricsView: View {
    let track: Track
    @State private var lyrics: Lyrics?
    @State private var isLoading = true
    
    private let musicService: MusicService = ITunesMusicService()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background
            AsyncImage(url: track.highResCoverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 80)
                    .overlay(Color.black.opacity(0.6))
            } placeholder: {
                Color.monetBackground
            }
            .ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                            .padding()
                    }
                }
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if let lyrics = lyrics {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(lyrics.lines, id: \.self) { line in
                                Text(line.text)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(32)
                    }
                } else {
                    Spacer()
                    Text("Текст песни недоступен")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
            }
        }
        .onAppear {
            loadLyrics()
        }
    }
    
    private func loadLyrics() {
        Task {
            do {
                let fetchedLyrics = try await musicService.getLyrics(track: track)
                await MainActor.run {
                    self.lyrics = fetchedLyrics
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
