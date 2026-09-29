import Foundation

extension RhythmPlaybackEngine {
    func startWave(_ first: Track) {
        play(first, queue: [first])
    }
}
