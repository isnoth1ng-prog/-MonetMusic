import SwiftUI

struct CleanPlayerBackground: View {
    @EnvironmentObject private var player: RhythmPlayer
    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()
            
            AsyncImage(url: player.currentTrack?.highResCoverURL) { phase in
                if case .success(let image) = phase {
                    image.resizable()
                        .scaledToFill()
                        .blur(radius: 70)
                        .opacity(0.30)
                }
            }
            
            LinearGradient(
                colors: [RhythmTheme.background.opacity(0.12), RhythmTheme.background.opacity(0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
