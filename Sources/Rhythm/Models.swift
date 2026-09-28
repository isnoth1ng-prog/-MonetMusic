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

    var highResCoverURL: URL? {
        guard let coverURL else { return nil }
        return URL(string: coverURL.absoluteString.replacingOccurrences(of: "100x100bb", with: "1000x1000bb")) ?? coverURL
    }
}

struct Artist: Identifiable, Hashable {
    let id: Int
    let name: String
    let genre: String?
    let imageURL: URL?
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
