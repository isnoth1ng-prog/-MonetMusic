import Foundation

enum PlaybackSourceID: String, CaseIterable {
    case audius = "Audius"
    case piped = "Piped"
}

struct PlaybackSession {
    let source: PlaybackSourceID
    let url: URL
    let duration: Double
}

@MainActor
protocol PlaybackSourceAdapter {
    var id: PlaybackSourceID { get }
    func prepare(_ track: Track) async throws -> PlaybackSession
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
            url: url,
            duration: Double(audius.duration ?? 0)
        )
    }
}

@MainActor
final class PipedSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .piped

    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard let resolved = await PipedService.shared.resolve(track) else {
            throw RhythmError.noResults
        }

        return PlaybackSession(
            source: id,
            url: resolved.url,
            duration: resolved.duration
        )
    }
}
