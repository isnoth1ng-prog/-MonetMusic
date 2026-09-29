import Foundation
import MusicKit

enum PlaybackSourceID: String, CaseIterable {
    case appleMusic = "Apple Music"
    case audius = "Audius"
    case piped = "Piped"
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

@MainActor protocol PlaybackSourceAdapter {
    var id: PlaybackSourceID { get }
    func prepare(_ track: Track) async throws -> PlaybackSession
}

@MainActor final class AppleMusicSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .appleMusic

    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard track.source == .catalog, let id = Int(track.id) else { throw RhythmError.noResults }
        guard await MusicAuthorization.request() == .authorized else { throw RhythmError.unauthorized }
        var request = MusicCatalogResourceRequest<Song>(matching: \\Song.id, equalTo: MusicItemID(String(id)))
        request.options = [.findEquivalents]
        let response = try await request.response()
        guard let song = response.items.first else { throw RhythmError.noResults }
        return PlaybackSession(source: id, payload: .appleMusic(song), duration: song.duration ?? track.duration)
    }
}

@MainActor final class AudiusSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .audius
    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard let value = await AudiusService.shared.resolve(track),
              let url = AudiusService.shared.streamURL(for: value.id) else { throw RhythmError.noResults }
        return PlaybackSession(source: id, payload: .remote(url), duration: Double(value.duration ?? 0))
    }
}

@MainActor final class PipedSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .piped
    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard let value = await PipedService.shared.resolve(track) else { throw RhythmError.noResults }
        return PlaybackSession(source: id, payload: .remote(value.url), duration: value.duration)
    }
}
