import Foundation
import AVFoundation
import MediaPlayer
import MusicKit

enum PlaybackStatus: Equatable {
    case idle, loading, playing, paused, failed
    var label: String {
        switch self {
        case .idle: "Готов"
        case .loading: "Подключение…"
        case .playing: "Играет"
        case .paused: "Пауза"
        case .failed: "Не удалось воспроизвести"
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
final class RhythmPlaybackEngine: ObservableObject {
    static let shared = RhythmPlaybackEngine()
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

    let avPlayer = AVPlayer()
    let applePlayer = ApplicationMusicPlayer.shared
    let adapters: [PlaybackSourceAdapter] = [AppleMusicSourceAdapter(), AudiusSourceAdapter(), PipedSourceAdapter()]
    var queue: [Track] = []
    var queueIndex = 0
    var generation = UUID()
    var attempted = Set<PlaybackSourceID>()
    var appleTask: Task<Void, Never>?
    var lyricsTask: Task<Void, Never>?
    var fallbackTask: Task<Void, Never>?
    var lastRecordedID: String?

    private var observer: Any?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?

    private init() {
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.playback, mode: .default, options: [])
        try? audio.setActive(true)

        observer = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.updateRemote() } }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, note.object as? AVPlayerItem === self.avPlayer.currentItem else { return }
            Task { @MainActor in self.advance() }
        }

        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, note.object as? AVPlayerItem === self.avPlayer.currentItem else { return }
            Task { @MainActor in self.remoteFailed(note.object as? AVPlayerItem) }
        }
    }

    deinit {
        if let observer { avPlayer.removeTimeObserver(observer) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        appleTask?.cancel(); lyricsTask?.cancel(); fallbackTask?.cancel()
    }

    func play(_ track: Track, queue: [Track] = []) {
        start(track, queue: queue.isEmpty ? [track] : queue)
    }

    func start(_ track: Track, queue: [Track]) {
        self.queue = queue
        queueIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        generation = UUID()
        attempted.removeAll()
        appleTask?.cancel(); lyricsTask?.cancel(); fallbackTask?.cancel()
        applePlayer.pause()
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)

        currentTrack = track
        status = .loading
        progress = 0
        duration = max(track.duration, 0)
        lyrics = []
        activeSource = nil
        streamError = nil
        diagnostics = []
        lastRecordedID = nil
        ListeningStore.shared.record(track)

        let g = generation
        Task { [weak self] in await self?.resolveAndPlay(track, generation: g) }
        lyricsTask = Task { [weak self] in
            guard let self else { return }
            let lines = await MusicCatalog.shared.lyrics(for: track)
            guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
            self.lyrics = lines
        }
    }

    private func resolveAndPlay(_ track: Track, generation g: UUID) async {
        for adapter in adapters where !attempted.contains(adapter.id) {
            guard g == generation else { return }
            attempted.insert(adapter.id)
            do {
                let session = try await adapter.prepare(track)
                guard g == generation else { return }
                switch session.payload {
                case .appleMusic(let song):
                    try await playApple(song, duration: session.duration, generation: g)
                case .remote(let url):
                    try await playRemote(url, source: session.source, duration: session.duration, generation: g)
                }
                return
            } catch {
                diagnostic(adapter.id, readable(error), false)
            }
        }
        guard g == generation else { return }
        activeSource = nil
        status = .failed
        streamError = "Не удалось запустить полный поток ни из одного источника."
        updateNowPlaying()
    }

    private func playApple(_ song: Song, duration: Double, generation g: UUID) async throws {
        activeSource = .appleMusic
        status = .loading
        self.duration = duration
        applePlayer.queue = [song]
        try await applePlayer.prepareToPlay()
        guard g == generation else { return }
        try await applePlayer.play()
        guard g == generation else { return }
        diagnostic(.appleMusic, "Apple Music: полный трек запущен", true)
        status = .playing
        streamError = nil

        appleTask?.cancel()
        appleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self, g == self.generation else { return }
                self.updateApple()
            }
        }
        updateApple()
    }

    private func updateApple() {
        guard activeSource == .appleMusic else { return }
        let time = applePlayer.playbackTime
        if time.isFinite { progress = max(0, time) }

        switch applePlayer.state.playbackStatus {
        case .playing, .seekingForward, .seekingBackward: status = .playing
        case .paused, .interrupted: status = .paused
        case .stopped:
            if duration > 0 && progress >= duration - 1.5 { advance() }
            else if status != .loading { status = .paused }
        }
        updateNowPlaying()
    }

    private func playRemote(_ url: URL, source: PlaybackSourceID, duration: Double, generation g: UUID) async throws {
        activeSource = source
        status = .loading
        if duration > 0 { self.duration = duration }
        let item = AVPlayerItem(url: url)
        avPlayer.replaceCurrentItem(with: item)
        avPlayer.play()
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard g == generation else { return }
        if item.status == .failed { throw item.error ?? RhythmError.badResponse }
        diagnostic(source, "Полный поток подключён", true)
        updateRemote()
    }

    func updateRemote() {
        guard activeSource != .appleMusic, activeSource != nil, let item = avPlayer.currentItem else { return }
        if item.status == .failed { remoteFailed(item); return }
        let time = avPlayer.currentTime().seconds
        if time.isFinite { progress = max(0, time) }
        let d = item.duration.seconds
        if d.isFinite && d > 0 { duration = d }
        switch avPlayer.timeControlStatus {
        case .playing: status = .playing
        case .waitingToPlayAtSpecifiedRate: status = .loading
        case .paused: if status != .failed { status = .paused }
        @unknown default: break
        }
        updateNowPlaying()
    }

    func remoteFailed(_ item: AVPlayerItem?) {
        guard let source = activeSource, source != .appleMusic else { return }
        diagnostic(source, readable(item?.error ?? RhythmError.badResponse), false)
        guard let track = currentTrack else { return }
        guard attempted != Set(adapters.map(\.id)) else {
            activeSource = nil; status = .failed
            streamError = "Все доступные источники не смогли отдать полный поток."
            return
        }
        let g = generation
        fallbackTask?.cancel()
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            await self.resolveAndPlay(track, generation: g)
        }
    }

    func toggle() { isPlaying ? pause() : resume() }

    func pause() {
        guard currentTrack != nil else { return }
        if activeSource == .appleMusic { applePlayer.pause() } else { avPlayer.pause() }
        status = .paused
        updateNowPlaying()
    }

    func resume() {
        guard currentTrack != nil else { return }
        if activeSource == .appleMusic {
            Task {
                do { try await applePlayer.play(); updateApple() }
                catch { diagnostic(.appleMusic, readable(error), false); remoteFailed(nil) }
            }
        } else if activeSource != nil {
            avPlayer.play(); status = .playing; updateNowPlaying()
        } else {
            generation = UUID(); attempted.removeAll(); status = .loading
            let g = generation
            if let track = currentTrack {
                Task { [weak self] in await self?.resolveAndPlay(track, generation: g) }
            }
        }
    }

    func seek(_ value: Double) {
        let target = max(0, min(value, max(duration, 1)))
        if activeSource == .appleMusic {
            applePlayer.playbackTime = target
        } else if activeSource != nil {
            avPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        progress = target
        updateNowPlaying()
    }

    func next() { advance() }
    func previous() {
        if progress > 4 { seek(0); return }
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        start(queue[queueIndex], queue: queue)
    }

    func toggleLike() { if let track = currentTrack { toggleLike(track) } }
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

    func advance() {
        record()
        guard !queue.isEmpty else { status = .idle; return }
        if repeatMode == .one, let track = currentTrack { start(track, queue: queue); return }
        if shuffle && queue.count > 1 {
            var n = Int.random(in: 0..<queue.count)
            while n == queueIndex { n = Int.random(in: 0..<queue.count) }
            queueIndex = n
        } else {
            queueIndex += 1
            if queueIndex >= queue.count {
                if repeatMode == .all { queueIndex = 0 }
                else { status = .idle; progress = duration; updateNowPlaying(); return }
            }
        }
        start(queue[queueIndex], queue: queue)
    }

    private func record() {
        guard let track = currentTrack, lastRecordedID != track.id else { return }
        ListeningStore.shared.noteListening(trackID: track.id, ratio: duration > 0 ? progress / duration : 0, liked: ListeningStore.shared.isLiked(track.id))
        lastRecordedID = track.id
    }

    private func diagnostic(_ source: PlaybackSourceID, _ message: String, _ success: Bool) {
        diagnostics.append(PlaybackDiagnostic(source: source.rawValue, message: message, succeeded: success))
        if diagnostics.count > 12 { diagnostics.removeFirst(diagnostics.count - 12) }
    }

    private func readable(_ error: Error) -> String {
        if let e = error as? RhythmError { return e.localizedDescription }
        return error.localizedDescription.isEmpty ? "Источник не ответил." : error.localizedDescription
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

typealias RhythmPlayer = RhythmPlaybackEngine
