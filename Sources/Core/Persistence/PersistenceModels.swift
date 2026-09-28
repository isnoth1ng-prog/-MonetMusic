import SwiftData
import Foundation

@Model
final class LibraryTrack {
    @Attribute(.unique) var id: String
    var title: String
    var artist: String
    var album: String?
    var coverURLString: String?
    var audioURLString: String?
    var duration: Double
    var genre: String?
    var isExplicit: Bool
    var addedAt: Date
    var playCount: Int = 0
    var lastPlayedAt: Date?

    init(track: Track) {
        self.id = track.id
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.coverURLString = track.coverURL?.absoluteString
        self.audioURLString = track.audioURL?.absoluteString
        self.duration = track.duration
        self.genre = track.genre
        self.isExplicit = track.isExplicit
        self.addedAt = Date()
    }

    var track: Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            coverURL: coverURLString.flatMap { URL(string: $0) },
            audioURL: audioURLString.flatMap { URL(string: $0) },
            duration: duration,
            genre: genre,
            releaseDate: nil,
            isExplicit: isExplicit
        )
    }
}

@Model
final class UserPlaylist {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var trackIDs: [String]

    init(id: UUID = UUID(), title: String, trackIDs: [String] = []) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.trackIDs = trackIDs
    }
}
