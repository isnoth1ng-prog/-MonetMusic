import Foundation
import AVFoundation
import MediaPlayer
import MusicKit

enum PlaybackStatus: Equatable {
    case idle, loading, playing, paused, failed
    var label: String {
        switch self {
        case .idle: return "Готов"
        case .loading: return "Подключение…"
        case .playing: return "Играет"
        case .paused: return "Пауза"
        case .failed: return "Не удалось воспроизвести"
        }
    }
}

struct PlaybackDiagnostic: Identifiable, Equatable {
    let id = UUID()
    let source: String
    let message: String
    let succeeded: Bool
}

@MainActor
final class PlaybackEngine: ObservableObject {
    static let shared = PlaybackEngine()

    @Published private(set) var currentTrack: Track?
    @Published private(set) var status: PlaybackStatus = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var lyrics: [LyricLine] = []
    @Published private(set) var activeSource: PlaybackSourceID?
    @Published private(set) var streamError: String?
    @Published private(set) var diagnostics: [PlaybackDiagnostic] = []
    @Published var repeatMode: RepeatMode = .off
    @Published var shuffle = false

    var isPlaying: Bool { status == .playing }
    var usingAppleMusic: Bool { activeSource == .appleMusic }
    var sourceLabel: String { activeSource?.rawValue ?? "Источник не выбран" }

    private let avPlayer = AVPlayer()
    private let applePlayer = ApplicationMusicPlayer.shared
    private let adapters: [PlaybackSourceAdapter] = [AppleMusicSourceAdapter(), AudiusSourceAdapter()]
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var queue: [Track] = []
    private var queueIndex = 0
    private var pollTask: Task<Void, Never>?
    private var waveTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var waveMode = false
    private var wavePlayedIDs = Set<String>()
    private var lastRecordedTrackID: String?
    private var playbackGeneration = UUID()
    private var attemptedSourceIDs = Set<PlaybackSourceID>()

    private init() {
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.playback, mode: .default, options: [])
        try? audio.setActive(true)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, note.object as? AVPlayerItem === self.avPlayer.currentItem else { return }
            Task { @MainActor in self.advance() }
        }

        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateRemoteState() }
        }
    }

    deinit {
        if let timeObserver { avPlayer.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        pollTask?.cancel(); waveTask?.cancel(); fallbackTask?.cancel()
    }

    func play(_ track: Track, queue: [Track] = []) {
        waveMode = false
        wavePlayedIDs.removeAll()
        playInternal(track, queue: queue.isEmpty ? [track] : queue)
    }

    private func playInternal(_ track: Track, queue: [Track]) {
        if !queue.isEmpty {
            self.queue = queue
            queueIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        }

        playbackGeneration = UUID()
        attemptedSourceIDs.removeAll()
        fallbackTask?.cancel()
        pollTask?.cancel()

        currentTrack = track
        progress = 0
        duration = max(track.duration, 0)
        lyrics = []
        activeSource = nil
        streamError = nil
        diagnostics = []
        status = .loading
        lastRecordedTrackID = nil
        ListeningStore.shared.record(track)

        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        applePlayer.stop()

        let generation = playbackGeneration
        Task { [weak self] in
            guard let self else { return }
            await self.startPlayback(track, generation: generation)
        }
        Task { [weak self] in
            guard let self else { return }
            let lines = await MusicCatalog.shared.lyrics(for: track)
            guard self.currentTrack?.id == track.id else { return }
            self.lyrics = lines
        }
    }

    private func startPlayback(_ track: Track, generation: UUID) async {
        for adapter in adapters {
            guard generation == playbackGeneration else { return }
            guard !attemptedSourceIDs.contains(adapter.id) else { continue }
            attemptedSourceIDs.insert(adapter.id)

            do {
                let session = try await adapter.prepare(track)
                guard generation == playbackGeneration else { return }

                switch session.payload {
                case .appleMusic(let song):
                    applePlayer.queue = [song]
                    try await applePlayer.play()
                    activeSource = .appleMusic
                    duration = session.duration > 0 ? session.duration : duration
                    status = .playing
                    streamError = nil
                    addDiagnostic(adapter.id, "Полный поток запущен", success: true)
                    startAppleMusicPolling(generation: generation)
                    updateNowPlaying()
                    return

                case .remote(let url):
                    try await startRemote(url, duration: session.duration, generation: generation)
                    return
                }
            } catch {
                addDiagnostic(adapter.id, readableError(error), success: false)
            }
        }

        guard generation == playbackGeneration else { return }
        activeSource = nil
        status = .failed
        streamError = "Полный поток не найден. 30-секундные превью Rhythm не воспроизводит."
        updateNowPlaying()
    }

    private func startRemote(_ url: URL, duration fallbackDuration: Double, generation: UUID) async throws {
        activeSource = .audius
        status = .loading
        let item = AVPlayerItem(url: url)
        avPlayer.replaceCurrentItem(with: item)
        avPlayer.play()
        if fallbackDuration > 0 { duration = fallbackDuration }

        try? await Task.sleep(nanoseconds: 500_000_000)
        guard generation == playbackGeneration else { return }
        if item.status == .failed { throw item.error ?? RhythmError.badResponse }

        addDiagnostic(.audius, "Полный MP3-поток подключён", success: true)
        updateRemoteState()
        updateNowPlaying()
    }

    private func updateRemoteState() {
        guard activeSource == .audius, let item = avPlayer.currentItem else { return }

        if item.status == .failed {
            let message = readableError(item.error ?? RhythmError.badResponse)
            if status != .failed {
                addDiagnostic(.audius, message, success: false)
                fallbackAfterRemoteFailure()
            }
            return
        }

        let seconds = avPlayer.currentTime().seconds
        if seconds.isFinite { progress = max(0, seconds) }
        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }

        switch avPlayer.timeControlStatus {
        case .playing: status = .playing
        case .waitingToPlayAtSpecifiedRate: status = .loading
        case .paused: if status != .failed { status = .paused }
        @unknown default: break
        }
        updateNowPlaying()
    }

    private func fallbackAfterRemoteFailure() {
        guard let track = currentTrack else { return }
        let all = Set(adapters.map { $0.id })
        guard attemptedSourceIDs != all else {
            status = .failed
            streamError = "Audius не отдал поток. Другого доступного полного источника для этого трека нет."
            return
        }

        let generation = playbackGeneration
        fallbackTask?.cancel()
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            status = .loading
            await startPlayback(track, generation: generation)
        }
    }

    private func startAppleMusicPolling(generation: UUID) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, generation == self.playbackGeneration else { return }
                let time = applePlayer.playbackTime
                if time.isFinite { progress = max(0, time) }

                switch applePlayer.state.playbackStatus {
                case .playing: status = .playing
                case .paused, .seekingBackward, .seekingForward, .interrupted: status = .paused
                case .stopped:
                    if duration > 0, progress >= duration - 1 { advance(); return }
                @unknown default: break
                }
                updateNowPlaying()
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    func toggle() { isPlaying ? pause() : resume() }

    func pause() {
        guard currentTrack != nil else { return }
        if usingAppleMusic { applePlayer.pause() }
        else if activeSource == .audius { avPlayer.pause() }
        status = .paused
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else { return }
        if usingAppleMusic {
            Task {
                do { try await applePlayer.play(); status = .playing }
                catch { status = .failed; streamError = "Apple Music не смог продолжить воспроизведение." }
            }
        } else if activeSource == .audius {
            avPlayer.play()
            status = .playing
        } else if let track = currentTrack {
            playbackGeneration = UUID()
            attemptedSourceIDs.removeAll()
            status = .loading
            Task { await startPlayback(track, generation: playbackGeneration) }
        }
        updateNowPlaying()
    }

    func seek(_ value: Double) {
        let target = max(0, min(value, max(duration, 1)))
        if usingAppleMusic { applePlayer.playbackTime = target }
        else if activeSource == .audius {
            avPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        }
        progress = target
        updateNowPlaying()
    }

    func next() { advance() }

    func previous() {
        if progress > 4 { seek(0); return }
        guard !queue.isEmpty else { return }
        if waveMode && queueIndex == 0 { seek(0); return }
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

    func isLiked(_ track: Track) -> Bool { ListeningStore.shared.isLiked(track.id) }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    private func advance() {
        recordCurrentListening()
        if waveMode { advanceWave(); return }
        guard !queue.isEmpty else { status = .idle; return }

        if repeatMode == .one, let currentTrack {
            playInternal(currentTrack, queue: queue); return
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
                else { status = .idle; progress = duration; updateNowPlaying(); return }
            }
        }
        playInternal(queue[queueIndex], queue: queue)
    }

    func startWave(_ first: Track) {
        waveTask?.cancel()
        waveMode = true
        wavePlayedIDs = [first.id]
        queue = [first]
        queueIndex = 0
        playInternal(first, queue: queue)
    }

    private func advanceWave() {
        guard let current = currentTrack else { return }
        status = .loading
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
                status = .failed
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

    private func addDiagnostic(_ source: PlaybackSourceID, _ message: String, success: Bool) {
        diagnostics.append(PlaybackDiagnostic(source: source.rawValue, message: message, succeeded: success))
        if diagnostics.count > 12 { diagnostics.removeFirst(diagnostics.count - 12) }
    }

    private func readableError(_ error: Error) -> String {
        (error as? RhythmError)?.localizedDescription ?? (error.localizedDescription.isEmpty ? "Источник не ответил." : error.localizedDescription)
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

typealias RhythmPlayer = PlaybackEngine
