import Foundation

struct Track: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var artist: String
    var album: String?
    var coverURL: URL?
    var audioURL: URL?
    var duration: Double
    var genre: String?
    var releaseDate: Date?
    var isExplicit: Bool
    
    // High-res cover URL helper for iTunes artwork
    var highResCoverURL: URL? {
        guard let urlString = coverURL?.absoluteString else { return nil }
        let highResString = urlString.replacingOccurrences(of: "100x100bb", with: "1000x1000bb")
        return URL(string: highResString) ?? coverURL
    }
}
