import Foundation

struct Artist: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var coverURL: URL?
    var genre: String?
}

struct Album: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var artist: String
    var coverURL: URL?
    var releaseDate: Date?
    var trackCount: Int
    var tracks: [Track]?
}

struct LyricsLine: Hashable, Codable {
    var text: String
    var timeStart: TimeInterval? // For synced lyrics
}

struct Lyrics: Hashable, Codable {
    var id: String
    var trackId: String
    var lines: [LyricsLine]
    var isSynced: Bool
}
