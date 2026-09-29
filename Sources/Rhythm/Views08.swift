import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject private var player: RhythmPlayer
    var body: some View { Text(player.currentTrack?.title ?? "Rhythm") }
}
