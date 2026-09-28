import Foundation

protocol MusicService {
    func search(query: String) async throws -> [Track]
    func getRecommendations(seedTracks: [Track]) async throws -> [Track]
    func getLyrics(track: Track) async throws -> Lyrics?
}

enum MusicServiceError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
}
