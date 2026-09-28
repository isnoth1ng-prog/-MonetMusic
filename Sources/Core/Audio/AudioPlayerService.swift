import Foundation
import AVFoundation
import MediaPlayer
import Combine
import UIKit

enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one

    var icon: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

final class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var currentStreamURL: URL?
    private var fallbackURL: URL?

    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var queue: [Track] = []
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .off

    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()

        let savedEQ = UserDefaults.standard.string(forKey: "eqPreset") ?? "Flat"
        applyEQ(preset: savedEQ)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFail(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: nil
        )
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func play(track: Track, queue: [Track] = []) {
        self.queue = queue.isEmpty ? [track] : queue
        self.currentTrack = track
        self.progress = 0
        self.duration = max(track.duration, 0)

        let useBackend = UserDefaults.standard.bool(forKey: "useBackend")
        let backend = UserDefaults.standard.string(forKey: "backendURL")?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if useBackend, let backendURL = makeBackendURL(backend, track: track) {
            start(track: track, url: backendURL, fallbackURL: track.audioURL)
        } else if let audioURL = track.audioURL {
            start(track: track, url: audioURL, fallbackURL: nil)
        }
    }

    private func start(track: Track, url: URL, fallbackURL: URL?) {
        removeCurrentObservers()

        let item = AVPlayerItem(url: url)
        currentStreamURL = url
        self.fallbackURL = fallbackURL

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        player?.play()
        isPlaying = true

        addPeriodicTimeObserver()
        updateNowPlayingInfo(track: track)
        ListeningHistory.shared.record(track)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    func togglePlayPause() {
        guard let player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }

        isPlaying.toggle()
        updateNowPlayingInfoPlaybackState()
    }

    func playNext() {
        guard !queue.isEmpty else { return }

        if repeatMode == .one, let currentTrack {
            play(track: currentTrack, queue: queue)
            return
        }

        if isShuffleEnabled {
            let candidates = queue.filter { $0.id != currentTrack?.id }
            if let next = candidates.randomElement() {
                play(track: next, queue: queue)
            }
            return
        }

        guard let currentTrack,
              let index = queue.firstIndex(of: currentTrack) else { return }

        if index + 1 < queue.count {
            play(track: queue[index + 1], queue: queue)
        } else if repeatMode == .all {
            play(track: queue[0], queue: queue)
        } else {
            isPlaying = false
            progress = 1
            player?.pause()
            updateNowPlayingInfoPlaybackState()
        }
    }

    func playPrevious() {
        guard let currentTrack,
              let index = queue.firstIndex(of: currentTrack) else {
            seek(to: 0)
            return
        }

        if progress > 0.08 {
            seek(to: 0)
        } else if index > 0 {
            play(track: queue[index - 1], queue: queue)
        } else if repeatMode == .all, let last = queue.last {
            play(track: last, queue: queue)
        } else {
            seek(to: 0)
        }
    }

    func seek(to percentage: Double) {
        guard let player,
              let itemDuration = player.currentItem?.duration else { return }

        let seconds = CMTimeGetSeconds(itemDuration)
        guard seconds.isFinite, seconds > 0 else { return }

        let clamped = min(max(percentage, 0), 1)
        player.seek(to: CMTime(seconds: seconds * clamped, preferredTimescale: 600))
        progress = clamped
        updateNowPlayingInfoPlaybackState()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    func applyEQ(preset: String) {
        UserDefaults.standard.set(preset, forKey: "eqPreset")
    }

    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        playNext()
    }

    @objc private func playerDidFail(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,
              item === player?.currentItem,
              let track = currentTrack,
              let fallbackURL,
              currentStreamURL != fallbackURL else { return }

        start(track: track, url: fallbackURL, fallbackURL: nil)
    }

    private func addPeriodicTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, let item = self.player?.currentItem else { return }

            let rawDuration = CMTimeGetSeconds(item.duration)
            let current = CMTimeGetSeconds(time)

            if rawDuration.isFinite, rawDuration > 0 {
                self.duration = rawDuration
                self.progress = min(max(current / rawDuration, 0), 1)
                self.updateNowPlayingInfoPlaybackState()
            }
        }
    }

    private func removeCurrentObservers() {
        if let item = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
    }

    private func makeBackendURL(_ value: String?, track: Track) -> URL? {
        guard let value, !value.isEmpty else { return nil }

        let normalized: String
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            normalized = value
        } else {
            normalized = "http://\(value):3000"
        }

        guard var components = URLComponents(string: normalized) else { return nil }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/stream"
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.artist) \(track.title)")
        ]
        return components.url
    }

    private func updateNowPlayingInfo(track: Track) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album ?? "",
            MPMediaItemPropertyPlaybackDuration: max(track.duration, 0),
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]

        if let url = track.highResCoverURL {
            Task {
                if let data = try? await URLSession.shared.data(from: url).0,
                   let image = UIImage(data: data) {
                    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingInfoPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress * duration
        info[MPMediaItemPropertyPlaybackDuration] = duration

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .success }
            self.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .success }
            self.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent,
                  self.duration > 0 else { return .commandFailed }

            self.seek(to: positionEvent.positionTime / self.duration)
            return .success
        }
    }
}
