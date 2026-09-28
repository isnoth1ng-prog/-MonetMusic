import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var queue: [Track] = []
    
    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func play(track: Track, queue: [Track] = []) {
        guard let url = track.audioURL else { return }
        
        self.queue = queue
        self.currentTrack = track
        
        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
        isPlaying = true
        self.duration = track.duration // Fallback duration, will be updated by observer
        
        addPeriodicTimeObserver()
        updateNowPlayingInfo(track: track)
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfoPlaybackState()
    }
    
    func playNext() {
        guard let current = currentTrack,
              let currentIndex = queue.firstIndex(of: current),
              currentIndex + 1 < queue.count else { return }
        play(track: queue[currentIndex + 1], queue: queue)
    }
    
    func playPrevious() {
        guard let current = currentTrack,
              let currentIndex = queue.firstIndex(of: current),
              currentIndex - 1 >= 0 else {
            seek(to: 0)
            return
        }
        play(track: queue[currentIndex - 1], queue: queue)
    }
    
    func seek(to percentage: Double) {
        guard let player = player, let duration = player.currentItem?.duration else { return }
        let durationSeconds = CMTimeGetSeconds(duration)
        guard !durationSeconds.isNaN else { return }
        
        let seekTimeSeconds = durationSeconds * percentage
        let seekTime = CMTime(seconds: seekTimeSeconds, preferredTimescale: 1000)
        player.seek(to: seekTime)
    }
    
    @objc private func playerDidFinishPlaying() {
        playNext()
    }
    
    private func addPeriodicTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            guard let self = self, let item = self.player?.currentItem else { return }
            let duration = CMTimeGetSeconds(item.duration)
            let current = CMTimeGetSeconds(time)
            
            if !duration.isNaN && duration > 0 {
                self.duration = duration
                self.progress = current / duration
            }
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo(track: Track) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = track.duration
        
        // Fetch artwork asynchronously
        if let url = track.highResCoverURL {
            Task {
                if let data = try? await URLSession.shared.data(from: url).0,
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func updateNowPlayingInfoPlaybackState() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        let rate: Float = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        if let currentItem = player?.currentItem {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(currentItem.currentTime())
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.playPrevious()
            return .success
        }
    }
}
