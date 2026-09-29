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

@MainActor
protocol PlaybackSourceAdapter {
    var id: PlaybackSourceID { get }
    func prepare(_ track: Track) async throws -> PlaybackSession
}

@MainActor
final class AppleMusicSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .appleMusic

    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard await MusicAuthorization.request() == .authorized else {
            throw RhythmError.noResults
        }

        var request = MusicCatalogSearchRequest(term: track.artist + " " + track.title, types: [Song.self])
        request.limit = 25
        let response = try await request.response()
        let songs = Array(response.songs)

        guard let song = songs
            .filter({ matches($0, track: track) })
            .sorted(by: { score($0, track: track) > score($1, track: track) })
            .first else {
            throw RhythmError.noResults
        }

        return PlaybackSession(source: .appleMusic, payload: .appleMusic(song), duration: song.duration ?? track.duration)
    }

    private func matches(_ song: Song, track: Track) -> Bool {
        let expectedTitle = normalized(track.title)
        let expectedArtist = normalized(track.artist)
        let title = normalized(song.title)
        let artist = normalized(song.artistName)

        let titleMatch = title == expectedTitle || title.contains(expectedTitle) || expectedTitle.contains(title)
        let artistMatch = artist == expectedArtist || artist.contains(expectedArtist) || expectedArtist.contains(artist)

        guard titleMatch && artistMatch else { return false }
        if let songDuration = song.duration, track.duration > 0 {
            return abs(songDuration - track.duration) <= 15
        }
        return true
    }

    private func score(_ song: Song, track: Track) -> Double {
        var value = 0.0
        if normalized(song.title) == normalized(track.title) { value += 20 }
        if normalized(song.artistName) == normalized(track.artist) { value += 20 }
        if let duration = song.duration, track.duration > 0 {
            value += max(0, 15 - abs(duration - track.duration))
        }
        if song.contentRating == .explicit && track.isExplicit { value += 2 }
        return value
    }

    private func normalized(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-zа-яё0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class AudiusSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .audius
    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard let value = await AudiusService.shared.resolve(track),
              let url = AudiusService.shared.streamURL(for: value.id) else { throw RhythmError.noResults }
        return PlaybackSession(source: id, payload: .remote(url), duration: Double(value.duration ?? 0))
    }
}

@MainActor
final class PipedSourceAdapter: PlaybackSourceAdapter {
    let id: PlaybackSourceID = .piped
    func prepare(_ track: Track) async throws -> PlaybackSession {
        guard let value = await PipedService.shared.resolve(track) else { throw RhythmError.noResults }
        return PlaybackSession(source: id, payload: .remote(value.url), duration: value.duration)
    }
}
