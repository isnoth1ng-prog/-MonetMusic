import Foundation
import AVFoundation
import MediaPlayer

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
    var sourceLabel: String { activeSource?.rawValue ?? "Источник не выбран" }

    private let avPlayer = AVPlayer()
    private let adapters: [PlaybackSourceAdapter] = [
        AudiusSourceAdapter(),
        PipedSourceAdapter()
    ]

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var queue: [Track] = []
    private var queueIndex = 0
    private var waveTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var lyricsTask: Task<Void, Never>?
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
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, note.object as? AVPlayerItem === self.avPlayer.currentItem else { return }
            Task { @MainActor in self.advance() }
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, note.object as? AVPlayerItem === self.avPlayer.currentItem else { return }
            Task { @MainActor in
                self.handleRemoteFailure(note.object as? AVPlayerItem)
            }
        }

        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRemoteState()
            }
        }
    }

    deinit {
        if let timeObserver { avPlayer.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }
        waveTask?.cancel()
        fallbackTask?.cancel()
        lyricsTask?.cancel()
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
        lyricsTask?.cancel()

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

        let generation = playbackGeneration

        Task { [weak self] in
            guard let self else { return }
            await self.startPlayback(track, generation: generation)
        }

        lyricsTask = Task { [weak self] in
            guard let self else { return }
            let lines = await MusicCatalog.shared.lyrics(for: track)
            guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
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

                try await startRemote(
                    session.url,
                    source: session.source,
                    duration: session.duration,
                    generation: generation
                )
                return
            } catch {
                addDiagnostic(adapter.id, readableError(error), success: false)
            }
        }

        guard generation == playbackGeneration else { return }
        activeSource = nil
        status = .failed
        streamError = "Полный поток не найден. Rhythm не воспроизводит 30-секундные превью."
        updateNowPlaying()
    }

    private func startRemote(
        _ url: URL,
        source: PlaybackSourceID,
        duration fallbackDuration: Double,
        generation: UUID
    ) async throws {
        activeSource = source
        status = .loading

        let item = AVPlayerItem(url: url)
        avPlayer.replaceCurrentItem(with: item)

        if fallbackDuration > 0 {
            duration = fallbackDuration
        }

        avPlayer.play()

        try? await Task.sleep(nanoseconds: 700_000_000)
        guard generation == playbackGeneration else { return }

        if item.status == .failed {
            throw item.error ?? RhythmError.badResponse
        }

        addDiagnostic(source, "Полный поток подключён", success: true)
        updateRemoteState()
        updateNowPlaying()
    }

    private func updateRemoteState() {
        guard let source = activeSource, let item = avPlayer.currentItem else { return }

        if item.status == .failed {
            handleRemoteFailure(item)
            return
        }

        let seconds = avPlayer.currentTime().seconds
        if seconds.isFinite {
            progress = max(0, seconds)
        }

        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 {
            duration = itemDuration
        }

        switch avPlayer.timeControlStatus {
        case .playing:
            status = .playing
        case .waitingToPlayAtSpecifiedRate:
            status = .loading
        case .paused:
            if status != .failed { status = .paused }
        @unknown default:
            break
        }

        if item.status == .readyToPlay {
            streamError = nil
        }

        if source == activeSource {
            updateNowPlaying()
        }
    }

    private func handleRemoteFailure(_ item: AVPlayerItem?) {
        guard let source = activeSource else { return }
        guard status != .failed || streamError == nil else { return }

        let message = readableError(item?.error ?? RhythmError.badResponse)
        addDiagnostic(source, message, success: false)
        fallbackAfterRemoteFailure()
    }

    private func fallbackAfterRemoteFailure() {
        guard let track = currentTrack else { return }

        let all = Set(adapters.map { $0.id })
        guard attemptedSourceIDs != all else {
            activeSource = nil
            status = .failed
            streamError = "Все доступные источники не смогли отдать полный поток."
            updateNowPlaying()
            return
        }

        let generation = playbackGeneration
        fallbackTask?.cancel()
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            avPlayer.pause()
            status = .loading
            await startPlayback(track, generation: generation)
        }
    }

    func toggle() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        guard currentTrack != nil else { return }
        avPlayer.pause()
        status = .paused
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else { return }

        if activeSource != nil {
            avPlayer.play()
            status = .playing
            updateNowPlaying()
            return
        }

        guard let track = currentTrack else { return }
        playbackGeneration = UUID()
        attemptedSourceIDs.removeAll()
        status = .loading

        let generation = playbackGeneration
        Task { [weak self] in
            guard let self else { return }
            await startPlayback(track, generation: generation)
        }
    }

    func seek(_ value: Double) {
        let target = max(0, min(value, max(duration, 1)))
        guard activeSource != nil else {
            progress = target
            return
        }

        avPlayer.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        progress = target
        updateNowPlaying()
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
            ListeningStore.shared.noteListening(
                trackID: track.id,
                ratio: progress / max(duration, 1),
                liked: true
            )
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
            status = .idle
            return
        }

        if repeatMode == .one, let currentTrack {
            playInternal(currentTrack, queue: queue)
            return
        }

        if shuffle {
            var nextIndex = Int.random(in: 0..<queue.count)
            if queue.count > 1 {
                while nextIndex == queueIndex {
                    nextIndex = Int.random(in: 0..<queue.count)
                }
            }
            queueIndex = nextIndex
        } else {
            queueIndex += 1

            if queueIndex >= queue.count {
                if repeatMode == .all {
                    queueIndex = 0
                } else {
                    status = .idle
                    progress = duration
                    updateNowPlaying()
                    return
                }
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

    private func addDiagnostic(
        _ source: PlaybackSourceID,
        _ message: String,
        success: Bool
    ) {
        diagnostics.append(
            PlaybackDiagnostic(
                source: source.rawValue,
                message: message,
                succeeded: success
            )
        )

        if diagnostics.count > 12 {
            diagnostics.removeFirst(diagnostics.count - 12)
        }
    }

    private func readableError(_ error: Error) -> String {
        if let rhythmError = error as? RhythmError {
            return rhythmError.localizedDescription
        }

        let message = error.localizedDescription
        return message.isEmpty ? "Источник не ответил." : message
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
