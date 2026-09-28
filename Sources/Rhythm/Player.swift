import Foundation
import AVFoundation
import MediaPlayer

@MainActor
final class RhythmPlayer: ObservableObject {
    static let shared = RhythmPlayer()

    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var lyrics: [LyricLine] = []
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffle = false

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var queue: [Track] = []
    private var queueIndex = 0

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.15, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            progress = max(0, time.seconds)
            if let itemDuration = player.currentItem?.duration.seconds,
               itemDuration.isFinite, itemDuration > 0 {
                duration = itemDuration
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func play(_ track: Track, queue: [Track] = []) {
        guard let url = track.audioURL else { return }
        if !queue.isEmpty {
            self.queue = queue
            self.queueIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        } else if self.queue.isEmpty {
            self.queue = [track]
            self.queueIndex = 0
        }

        currentTrack = track
        progress = 0
        duration = track.duration
        lyrics = []
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        isPlaying = true

        let captured = track
        Task {
            let lines = await MusicCatalog.shared.lyrics(for: captured)
            guard currentTrack?.id == captured.id else { return }
            lyrics = lines
        }

        Task {
            guard let item = player.currentItem else { return }
            let value = try? await item.asset.load(.duration)
            let seconds = value?.seconds ?? 0
            if seconds.isFinite, seconds > 0, currentTrack?.id == captured.id {
                duration = seconds
            }
        }

        ListeningStore.shared.record(track)
        updateNowPlaying()
    }

    func startWave(_ tracks: [Track]) {
        guard let first = tracks.first else { return }
        queue = tracks
        queueIndex = 0
        play(first, queue: tracks)
    }

    func toggle() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func seek(_ value: Double) {
        let target = max(0, min(value, duration))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        progress = target
    }

    func next() {
        advance()
    }

    func previous() {
        if progress > 4 {
            seek(0)
            return
        }
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        play(queue[queueIndex], queue: queue)
    }

    func toggleLike() {
        guard let currentTrack else { return }
        ListeningStore.shared.toggleLike(currentTrack)
        objectWillChange.send()
    }

    func isLiked(_ track: Track) -> Bool {
        ListeningStore.shared.isLiked(track.id)
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    private func advance() {
        guard !queue.isEmpty else {
            isPlaying = false
            return
        }
        if repeatMode == .one, let currentTrack {
            play(currentTrack, queue: queue)
            return
        }

        if shuffle {
            var nextIndex = Int.random(in: 0..<queue.count)
            if queue.count > 1 {
                while nextIndex == queueIndex { nextIndex = Int.random(in: 0..<queue.count) }
            }
            queueIndex = nextIndex
        } else {
            queueIndex += 1
            if queueIndex >= queue.count {
                if repeatMode == .all { queueIndex = 0 }
                else {
                    isPlaying = false
                    progress = duration
                    return
                }
            }
        }
        play(queue[queueIndex], queue: queue)
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
