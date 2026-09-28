import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let artist: String
    let artistID: Int?
    let album: String?
    let albumID: Int?
    let coverURL: URL?
    let audioURL: URL?
    let duration: Double
    let genre: String?
    let releaseDate: Date?
    let isExplicit: Bool
    let source: TrackSource

    var highResCoverURL: URL? {
        guard let coverURL else { return nil }
        let value = coverURL.absoluteString
            .replacingOccurrences(of: "100x100bb", with: "1000x1000bb")
            .replacingOccurrences(of: "100x100-75", with: "1000x1000-75")
        return URL(string: value) ?? coverURL
    }

    enum TrackSource: String, Codable, Hashable {
        case appleMusicCatalog
        case audius
        case previewFallback
    }

    init(
        id: String,
        title: String,
        artist: String,
        artistID: Int?,
        album: String?,
        albumID: Int?,
        coverURL: URL?,
        audioURL: URL?,
        duration: Double,
        genre: String?,
        releaseDate: Date?,
        isExplicit: Bool,
        source: TrackSource = .appleMusicCatalog
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistID = artistID
        self.album = album
        self.albumID = albumID
        self.coverURL = coverURL
        self.audioURL = audioURL
        self.duration = duration
        self.genre = genre
        self.releaseDate = releaseDate
        self.isExplicit = isExplicit
        self.source = source
    }
}

struct Artist: Identifiable, Hashable {
    let id: Int
    let name: String
    let genre: String?
    let imageURL: URL?
}

struct Album: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let artistID: Int?
    let coverURL: URL?
    let releaseDate: Date?
    let type: AlbumType
    let trackCount: Int

    enum AlbumType: String, Hashable {
        case album = "Альбом"
        case ep = "EP"
        case single = "Сингл"
        case other = "Релиз"
    }
}

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let time: Double
}

enum RepeatMode: String {
    case off, all, one
    var icon: String { self == .one ? "repeat.1" : "repeat" }
}
