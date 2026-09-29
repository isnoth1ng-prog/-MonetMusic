import SwiftUI

struct AdaptivePlayerBackground: View {
    let url: URL?
    var body: some View {
        ZStack {
            RhythmTheme.background.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                if case .success(let image) {
                    image.resizable().scaledToFill().blur(radius: 70).opacity(0.28)
                }
            }
            LinearGradient(colors: [RhythmTheme.background.opacity(0.12), RhythmTheme.background.opacity(0.94)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}
