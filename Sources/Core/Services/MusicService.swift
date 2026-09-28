import Foundation

protocol MusicService {
    func search(query: String) async throws -> [Track]
    func getRecommendations(seedTracks: [Track]) async throws -> [Track]
    func getLyrics(track: Track) async throws -> Lyrics?
}

enum MusicServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес сервиса"
        case .invalidResponse:
            return "Сервис не вернул корректный ответ"
        case .httpStatus(let status):
            return "Сервис вернул HTTP \(status)"
        case .decodingError:
            return "Не удалось прочитать ответ сервиса"
        }
    }
}
