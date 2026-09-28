import Foundation
import MusicKit

enum PlaybackSourceID: String, CaseIterable {
    case appleMusic = "Apple Music"
    case audius = "Audius"
}

enum PlaybackPayload {
    case appleMusic(Song)
    case remote(URL)
}

struct PlaybackSession {
    let source: PlaybackSourceID
    let payload: PlaybackPayload
    let duration: Double
}

@MainActor
protocol PlaybackSourceAdapter {
    var id: PlaybackSourceID { get }
    func prepare(_ track: Track) async throws -> PlaybackSession
}

@MainActor
final class AppleMusicSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .appleMusic

    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard await AppleMusicService.shared.requestAuthorization() else {
            throw RhythmError.unauthorized
        }

        let song = try await AppleMusicService.shared.resolveSong(for: track)
        guard song.title.caseInsensitiveCompare(track.title) == .orderedSame,
              song.artistName.caseInsensitiveCompare(track.artist) == .orderedSame else {
            throw RhythmError.mismatch
        }

        let songDuration = song.duration ?? track.duration
        if track.duration > 0, songDuration > 0, abs(songDuration - track.duration) > 8 {
            throw RhythmError.mismatch
        }

        return PlaybackSession(
            source: id,
            payload: .appleMusic(song),
            duration: songDuration
        )
    }
}

@MainActor
final class AudiusSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .audius

    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard let audius = await AudiusService.shared.resolve(track),
              let url = AudiusService.shared.streamURL(for: audius.id) else {
            throw RhythmError.noResults
        }

        return PlaybackSession(
            source: id,
            payload: .remote(url),
            duration: Double(audius.duration ?? 0)
        )
    }
}
