import Foundation
import MusicKit

enum RhythmError: LocalizedError {
    case badResponse, noResults
    var errorDescription: String? {
        switch self {
        case .badResponse: return "Музыкальный каталог временно недоступен."
        case .noResults: return "Ничего не найдено."
        }
    }
}

final class MusicCatalog {
    static let shared = MusicCatalog()
    private let session: URLSession

    private init() {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 12
        c.timeoutIntervalForResource = 20
        c.waitsForConnectivity = true
        session = URLSession(configuration: c)
    }

    private struct Response: Decodable { let results: [Item] }
    private struct Item: Decodable {
        let wrapperType: String?
        let kind: String?
        let artistId: Int?
        let trackId: Int?
        let artistName: String?
        let trackName: String?
        let collectionName: String?
        let collectionId: Int?
        let artworkUrl100: String?
        let previewUrl: String?
        let trackTimeMillis: Int?
        let primaryGenreName: String?
        let releaseDate: String?
        let trackExplicitness: String?
    }

    func search(_ query: String) async throws -> (tracks: [Track], artists: [Artist]) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ([], []) }
        var tracks: [Track] = []
        for country in ["ru", "us", "de"] {
            let url = searchURL(term: q, country: country, entity: "song", limit: 50)
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { continue }
            if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
                tracks.append(contentsOf: decoded.results.compactMap(makeTrack))
            }
            if tracks.count >= 50 { break }
        }

        var artists: [Artist] = []
        for country in ["ru", "us"] {
            let url = searchURL(term: q, country: country, entity: "musicArtist", limit: 15)
            if let (data, response) = try? await session.data(from: url),
               let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
               let decoded = try? JSONDecoder().decode(Response.self, from: data) {
                artists.append(contentsOf: decoded.results.compactMap(makeArtist))
            }
        }

        let uniqueTracks = Dictionary(grouping: tracks, by: \.id).compactMap { $0.value.first }
        let uniqueArtists = Dictionary(grouping: artists, by: \.id).compactMap { $0.value.first }
        return (Array(uniqueTracks.prefix(60)), Array(uniqueArtists.prefix(15)))
    }

    func artistTracks(id: Int) async throws -> [Track] {
        var c = URLComponents(string: "https://itunes.apple.com/lookup")!
        c.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "200")
        ]
        let (data, response) = try await session.data(from: c.url!)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw RhythmError.badResponse }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.results.compactMap(makeTrack)
    }

    func lyrics(for track: Track) async -> [LyricLine] {
        var c = URLComponents(string: "https://lrclib.net/api/get")!
        c.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album ?? ""),
            URLQueryItem(name: "duration", value: String(Int(track.duration)))
        ]
        guard let (data, response) = try? await session.data(from: c.url!),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return [] }

        struct LRC: Decodable { let syncedLyrics: String?; let plainLyrics: String? }
        guard let value = try? JSONDecoder().decode(LRC.self, from: data) else { return [] }
        if let synced = value.syncedLyrics { return parseLRC(synced) }
        return (value.plainLyrics ?? "").components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { LyricLine(text: $0, time: 0) }
    }

    func wave(seed: Track? = nil, favorites: [Track], history: [Track]) async -> [Track] {
        var seeds = [Track]()
        if let seed { seeds.append(seed) }
        seeds.append(contentsOf: favorites.prefix(5))
        seeds.append(contentsOf: history.prefix(8))
        var candidates: [Track] = []
        let artists = Array(Set(seeds.map { $0.artist }))
        let genres = Array(Set(seeds.compactMap { $0.genre }))

        for artist in artists.prefix(3) {
            if let result = try? await search(artist).tracks { candidates.append(contentsOf: result) }
        }
        for genre in genres.prefix(2) {
            if let result = try? await search(genre).tracks { candidates.append(contentsOf: result) }
        }

        if candidates.isEmpty {
            if let result = try? await search("music").tracks { candidates = result }
        }

        let blocked = Set(seeds.map { $0.id })
        var unique = Dictionary(grouping: candidates.filter { !blocked.contains($0.id) }, by: { $0.id })
            .compactMap { $0.value.first }
        unique.sort {
            let left = score($0, seeds: seeds)
            let right = score($1, seeds: seeds)
            if left == right { return $0.title < $1.title }
            return left > right
        }
        return Array(unique.prefix(30))
    }

    private func score(_ track: Track, seeds: [Track]) -> Int {
        var value = 0
        for seed in seeds {
            if track.artist.caseInsensitiveCompare(seed.artist) == .orderedSame { value += 5 }
            if let a = track.genre, let b = seed.genre, a.caseInsensitiveCompare(b) == .orderedSame { value += 2 }
            if track.albumID == seed.albumID { value += 1 }
        }
        return value
    }

    private func searchURL(term: String, country: String, entity: String, limit: Int) -> URL {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return c.url!
    }

    private func makeTrack(_ item: Item) -> Track? {
        guard let id = item.trackId, let title = item.trackName, let artist = item.artistName else { return nil }
        return Track(
            id: String(id), title: title, artist: artist, artistID: item.artistId,
            album: item.collectionName, albumID: item.collectionId,
            coverURL: item.artworkUrl100.flatMap(URL.init(string:)),
            audioURL: item.previewUrl.flatMap(URL.init(string:)),
            duration: Double(item.trackTimeMillis ?? 0) / 1000,
            genre: item.primaryGenreName,
            releaseDate: item.releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) },
            isExplicit: item.trackExplicitness == "explicit"
        )
    }

    private func makeArtist(_ item: Item) -> Artist? {
        guard let id = item.artistId, let name = item.artistName else { return nil }
        return Artist(id: id, name: name, genre: item.primaryGenreName, imageURL: nil)
    }

    private func parseLRC(_ text: String) -> [LyricLine] {
        let pattern = #"\[(\d+):(\d+(?:\.\d+)?)\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return text.components(separatedBy: .newlines).compactMap { line in
            let range = NSRange(location: 0, length: line.utf16.count)
            guard let match = regex.firstMatch(in: line, range: range),
                  let r1 = Range(match.range(at: 1), in: line),
                  let r2 = Range(match.range(at: 2), in: line),
                  let r3 = Range(match.range(at: 3), in: line) else { return nil }
            let minutes = Double(line[r1]) ?? 0
            let seconds = Double(line[r2]) ?? 0
            let text = line[r3].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return LyricLine(text: text, time: minutes * 60 + seconds)
        }.sorted { $0.time < $1.time }
    }
}

@MainActor
final class AppleMusicService: ObservableObject {
    static let shared = AppleMusicService()

    @Published private(set) var authorization = MusicAuthorization.currentStatus

    private init() {}

    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        authorization = status
        return status == .authorized
    }

    func resolveSong(for track: Track) async throws -> Song {
        let request = MusicCatalogSearchRequest(
            term: "(track.artist) (track.title)",
            types: [Song.self]
        )
        var mutable = request
        mutable.limit = 5
        let response = try await mutable.response()

        if let exact = response.songs.first(where: {
            $0.title.caseInsensitiveCompare(track.title) == .orderedSame &&
            $0.artistName.caseInsensitiveCompare(track.artist) == .orderedSame
        }) {
            return exact
        }
        if let first = response.songs.first {
            return first
        }
        throw RhythmError.noResults
    }
}
