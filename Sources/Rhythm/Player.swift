import Foundation
import AVFoundation
import MediaPlayer
import MusicKit

@MainActor
final class RhythmPlayer: ObservableObject {
    static let shared = RhythmPlayer()

    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var lyrics: [LyricLine] = []
    @Published private(set) var usingAppleMusic = false
    @Published private(set) var streamError: String?
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffle = false

    private let avPlayer = AVPlayer()
    private let applePlayer = ApplicationMusicPlayer.shared
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var queue: [Track] = []
    private var queueIndex = 0
    private var pollTask: Task<Void, Never>?
    private var waveTask: Task<Void, Never>?
    private var waveMode = false
    private var wavePlayedIDs = Set<String>()
    private var lastRecordedTrackID: String?

    private init() {
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.playback, mode: .default, options: [])
        try? audio.setActive(true)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, notification.object as? AVPlayerItem === self.avPlayer.currentItem else { return }
            Task { @MainActor in self.advance() }
        }

        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, !self.usingAppleMusic else { return }
            progress = max(0, time.seconds)
            if let itemDuration = avPlayer.currentItem?.duration.seconds,
               itemDuration.isFinite, itemDuration > 0 {
                duration = itemDuration
            }
            updateNowPlaying()
        }
    }

    deinit {
        if let timeObserver { avPlayer.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        pollTask?.cancel()
        waveTask?.cancel()
    }

    func play(_ track: Track, queue: [Track] = []) {
        waveMode = false
        wavePlayedIDs.removeAll()
        playInternal(track, queue: queue.isEmpty ? [track] : queue)
    }

    private func playInternal(_ track: Track, queue: [Track]) {
        if !queue.isEmpty {
            self.queue = queue
            self.queueIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        }

        currentTrack = track
        progress = 0
        duration = max(track.duration, 0)
        lyrics = []
        streamError = nil
        lastRecordedTrackID = nil
        ListeningStore.shared.record(track)

        pollTask?.cancel()
        Task { await playOnPhone(track) }

        Task {
            let lines = await MusicCatalog.shared.lyrics(for: track)
            guard currentTrack?.id == track.id else { return }
            lyrics = lines
        }
    }

    func startWave(_ first: Track) {
        waveTask?.cancel()
        waveMode = true
        wavePlayedIDs = [first.id]
        queue = [first]
        queueIndex = 0
        playInternal(first, queue: queue)
    }

    private func playOnPhone(_ track: Track) async {
        if await AppleMusicService.shared.requestAuthorization() {
            do {
                let song = try await AppleMusicService.shared.resolveSong(for: track)
                applePlayer.queue = [song]
                try await applePlayer.play()
                usingAppleMusic = true
                isPlaying = true
                duration = song.duration ?? max(track.duration, 0)
                startAppleMusicPolling()
                updateNowPlaying()
                return
            } catch {
                usingAppleMusic = false
                streamError = "Apple Music не смог запустить полный трек. Доступен резервный предпросмотр."
            }
        }

        usingAppleMusic = false
        guard let url = track.audioURL else {
            isPlaying = false
            streamError = "Полный поток для этого трека недоступен."
            return
        }

        avPlayer.replaceCurrentItem(with: AVPlayerItem(url: url))
        avPlayer.play()
        isPlaying = true

        let captured = track
        if let item = avPlayer.currentItem {
            let value = try? await item.asset.load(.duration)
            let seconds = value?.seconds ?? 0
            if seconds.isFinite, seconds > 0, currentTrack?.id == captured.id {
                duration = seconds
            }
        }
        updateNowPlaying()
    }

    private func startAppleMusicPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let time = applePlayer.playbackTime
                if time.isFinite { progress = max(0, time) }
                let status = applePlayer.state.playbackStatus
                isPlaying = status == .playing
                updateNowPlaying()

                if status == .stopped, duration > 0, progress >= duration - 1 {
                    advance()
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func toggle() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        if usingAppleMusic { applePlayer.pause() } else { avPlayer.pause() }
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else { return }
        if usingAppleMusic {
            Task {
                do { try await applePlayer.play() }
                catch { streamError = "Не удалось продолжить воспроизведение." }
            }
        } else {
            avPlayer.play()
        }
        isPlaying = true
        updateNowPlaying()
    }

    func seek(_ value: Double) {
        let target = max(0, min(value, max(duration, 1)))
        if usingAppleMusic {
            applePlayer.playbackTime = target
        } else {
            avPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        }
        progress = target
        updateNowPlaying()
    }

    func next() { advance() }

    func previous() {
        if progress > 4 {
            seek(0)
            return
        }
        guard !queue.isEmpty else { return }
        if waveMode && queueIndex == 0 {
            seek(0)
            return
        }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        playInternal(queue[queueIndex], queue: queue)
    }

    func toggleLike() {
        guard let currentTrack else { return }
        toggleLike(currentTrack)
    }

    func toggleLike(_ track: Track) {
        ListeningStore.shared.toggleLike(track)
        if ListeningStore.shared.isLiked(track.id) {
            ListeningStore.shared.noteListening(trackID: track.id, ratio: progress / max(duration, 1), liked: true)
        }
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
        recordCurrentListening()
        if waveMode {
            advanceWave()
            return
        }

        guard !queue.isEmpty else {
            isPlaying = false
            return
        }

        if repeatMode == .one, let currentTrack {
            playInternal(currentTrack, queue: queue)
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
        playInternal(queue[queueIndex], queue: queue)
    }

    private func advanceWave() {
        guard let current = currentTrack else { return }
        isPlaying = false
        waveTask?.cancel()
        waveTask = Task { [weak self] in
            guard let self else { return }
            let next = await MusicCatalog.shared.nextWaveTrack(
                current: current,
                favorites: ListeningStore.shared.favorites,
                history: ListeningStore.shared.history,
                playedIDs: wavePlayedIDs
            )
            guard !Task.isCancelled else { return }
            guard let next else {
                waveMode = false
                streamError = "Rhythm не нашёл новый подходящий трек."
                return
            }
            wavePlayedIDs.insert(next.id)
            queue.append(next)
            queueIndex = queue.count - 1
            playInternal(next, queue: queue)
        }
    }

    private func recordCurrentListening() {
        guard let track = currentTrack, lastRecordedTrackID != track.id else { return }
        let ratio = duration > 0 ? progress / duration : 0
        ListeningStore.shared.noteListening(
            trackID: track.id,
            ratio: ratio,
            liked: ListeningStore.shared.isLiked(track.id)
        )
        lastRecordedTrackID = track.id
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
    }
}
