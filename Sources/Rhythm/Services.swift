import Foundation

enum RhythmError: LocalizedError {
    case badResponse
    case noResults
    case mismatch

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Источник музыки не ответил корректно."
        case .noResults: return "Точный полный трек у источника не найден."
        case .mismatch: return "Источник вернул другой трек или несовпадающую длительность."
        }
    }
}


final class AudiusService {
    static let shared = AudiusService()

    private let session: URLSession
    private let baseURL = "https://discoveryprovider.audius.co/v1"

    struct TrackResponse: Decodable {
        let id: String
        let title: String
        let duration: Int?
        let isStreamable: String?
        let releaseDate: String?
        let genre: String?
        let artwork: Artwork?
        let user: User
        let isStreamGated: Bool?

        struct Artwork: Decodable {
            let `_1000x1000`: String?
            let `_480x480`: String?
        }

        struct User: Decodable {
            let id: String
            let name: String
        }
    }

    private struct SearchResponse: Decodable {
        let data: [TrackResponse]
    }

    private init() {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 10
        c.timeoutIntervalForResource = 15
        c.waitsForConnectivity = true
        session = URLSession(configuration: c)
    }

    func search(_ query: String, limit: Int = 25) async -> [TrackResponse] {
        var components = URLComponents(string: baseURL + "/tracks/search")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort_method", value: "relevant")
        ]

        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode,
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            return []
        }

        return decoded.data.filter(isPlayable)
    }

    func resolve(_ track: Track) async -> TrackResponse? {
        let query = "\(track.artist) \(track.title)"
        let candidates = await search(query, limit: 15)

        return candidates.first { candidate in
            normalized(candidate.title) == normalized(track.title) &&
            normalized(candidate.user.name) == normalized(track.artist)
        } ?? candidates.first { candidate in
            normalized(candidate.title) == normalized(track.title)
        }
    }

    func streamURL(for id: String) -> URL? {
        URL(string: baseURL + "/tracks/\(id)/stream")
    }

    func makeTrack(_ value: TrackResponse) -> Track? {
        guard isPlayable(value),
              let streamURL = streamURL(for: value.id) else { return nil }

        let artworkString = value.artwork?._1000x1000 ?? value.artwork?._480x480
        return Track(
            id: "audius:\(value.id)",
            title: value.title,
            artist: value.user.name,
            artistID: nil,
            album: nil,
            albumID: nil,
            coverURL: artworkString.flatMap(URL.init(string:)),
            audioURL: streamURL,
            duration: Double(value.duration ?? 0),
            genre: value.genre,
            releaseDate: value.releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) },
            isExplicit: false,
            source: .audius
        )
    }

    private func isPlayable(_ value: TrackResponse) -> Bool {
        let streamable = value.isStreamable?.lowercased() == "true"
        let title = value.title.lowercased()
        let blocked = ["karaoke", "tribute", "bootleg", "reupload", "re-upload", "unofficial", "nightcore", "8d audio", "sped up", "slowed", "ai cover", "type beat", "instrumental cover"].contains { title.contains($0) }
        return streamable && value.isStreamGated != true && (value.duration ?? 0) >= 45 && !blocked
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-zа-яё0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class PipedService {
    static let shared = PipedService()

    struct Resolved {
        let url: URL
        let duration: Double
        let instance: String
    }

    private struct SearchResponse: Decodable {
        let items: [SearchItem]
    }

    private struct SearchItem: Decodable {
        let type: String?
        let duration: Int?
        let title: String?
        let uploaderName: String?
        let url: String?
    }

    private struct StreamResponse: Decodable {
        let audioStreams: [AudioStream]?
        let duration: Int?
        let title: String?
        let livestream: Bool?
    }

    private struct AudioStream: Decodable {
        let url: String?
        let format: String?
        let mimeType: String?
        let codec: String?
        let bitrate: Int?
        let videoOnly: Bool?
    }

    private struct Instance: Decodable {
        let apiUrl: String
        let cdn: Bool?
        let uptime24h: Double?
    }

    private let session: URLSession
    private let fallbackInstances = [
        "https://pipedapi.kavin.rocks",
        "https://pipedapi.leptons.xyz",
        "https://pipedapi.nosebs.ru",
        "https://pipedapi-libre.kavin.rocks",
        "https://piped-api.privacy.com.de",
        "https://pipedapi.adminforge.de",
        "https://api.piped.yt",
        "https://pipedapi.drgns.space",
        "https://pipedapi.owo.si",
        "https://pipedapi.ducks.party"
    ]
    private var cachedInstances: [String]?
    private var quarantinedUntil: [String: Date] = [:]

    private init() {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 12
        c.waitsForConnectivity = true
        session = URLSession(configuration: c)
    }

    func resolve(_ track: Track) async -> Resolved? {
        let instances = await loadInstances()
        let queries = [
            "(track.artist) (track.title)",
            "(track.title) (track.artist)"
        ]

        for base in instances where !isQuarantined(base) {
            do {
                var candidates: [SearchItem] = []

                for query in queries {
                    candidates.append(contentsOf: try await search(query, baseURL: base))
                    if let best = bestCandidate(candidates, for: track) {
                        if let resolved = try await stream(for: best, baseURL: base, expected: track) {
                            return resolved
                        }
                    }
                }

                throw RhythmError.noResults
            } catch {
                quarantine(base)
            }
        }

        return nil
    }

    private func search(_ query: String, baseURL: String) async throws -> [SearchItem] {
        var c = URLComponents(string: baseURL + "/search")!
        c.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "filter", value: "music_songs")
        ]

        let request = URLRequest(url: c.url!)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw RhythmError.badResponse
        }

        return try JSONDecoder().decode(SearchResponse.self, from: data).items
            .filter { $0.type == "stream" }
    }

    private func stream(
        for candidate: SearchItem,
        baseURL: String,
        expected: Track
    ) async throws -> Resolved? {
        guard let videoID = videoID(from: candidate.url),
              let url = URL(string: baseURL + "/streams/" + videoID) else {
            return nil
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw RhythmError.badResponse
        }

        let value = try JSONDecoder().decode(StreamResponse.self, from: data)
        guard value.livestream != true else { return nil }

        let resolvedDuration = Double(value.duration ?? candidate.duration ?? 0)
        guard durationMatches(resolvedDuration, expected.duration) else { return nil }
        guard titleMatches(value.title ?? candidate.title ?? "", expected.title) else { return nil }

        guard let audio = selectAudio(value.audioStreams ?? []),
              let streamURL = URL(string: audio.url) else {
            return nil
        }

        return Resolved(
            url: streamURL,
            duration: resolvedDuration,
            instance: baseURL
        )
    }

    private func selectAudio(_ streams: [AudioStream]) -> AudioStream? {
        let usable = streams.filter {
            guard let url = $0.url, URL(string: url) != nil else { return false }
            guard $0.videoOnly != true else { return false }

            let format = ($0.format ?? "").uppercased()
            let mime = ($0.mimeType ?? "").lowercased()
            return format == "M4A"
                || format == "MP3"
                || mime == "audio/mp4"
                || mime == "audio/mpeg"
        }

        return usable.sorted { lhs, rhs in
            let leftFormat = (lhs.format ?? "").uppercased()
            let rightFormat = (rhs.format ?? "").uppercased()
            let leftPreferred = leftFormat == "M4A" || (lhs.mimeType ?? "").lowercased() == "audio/mp4"
            let rightPreferred = rightFormat == "M4A" || (rhs.mimeType ?? "").lowercased() == "audio/mp4"

            if leftPreferred != rightPreferred {
                return leftPreferred
            }
            return (lhs.bitrate ?? 0) > (rhs.bitrate ?? 0)
        }.first
    }

    private func bestCandidate(_ candidates: [SearchItem], for track: Track) -> SearchItem? {
        let scored = candidates.compactMap { candidate -> (SearchItem, Double)? in
            guard let title = candidate.title, !isNoise(title) else { return nil }
            let normalizedTitle = normalized(title)
            let expectedTitle = normalized(track.title)
            let expectedArtist = normalized(track.artist)

            let exactTitle = normalizedTitle == expectedTitle
            let titleContains = normalizedTitle.contains(expectedTitle)
            let artistInTitle = normalizedTitle.contains(expectedArtist)
            let uploaderMatches = normalized(candidate.uploaderName ?? "") == expectedArtist

            guard exactTitle || titleContains else { return nil }

            var score = 0.0
            if exactTitle { score += 8 }
            if titleContains { score += 4 }
            if artistInTitle { score += 5 }
            if uploaderMatches { score += 4 }

            if let duration = candidate.duration, track.duration > 0 {
                let delta = abs(Double(duration) - track.duration)
                if delta <= 6 { score += 6 }
                else if delta <= 12 { score += 2 }
                else { return nil }
            }

            return (candidate, score)
        }

        return scored.max { $0.1 < $1.1 }?.0
    }

    private func loadInstances() async -> [String] {
        if let cachedInstances, !cachedInstances.isEmpty {
            return cachedInstances
        }

        // Team Piped maintains the public list as a live source. We keep a
        // known-good fallback list so a temporary list fetch failure never
        // breaks playback completely.
        let listURL = URL(string: "https://raw.githubusercontent.com/TeamPiped/documentation/main/content/docs/public-instances/index.md")!
        if let (data, response) = try? await session.data(from: listURL),
           let http = response as? HTTPURLResponse,
           200..<300 ~= http.statusCode,
           let markdown = String(data: data, encoding: .utf8) {
            let parsed = markdown
                .split(separator: "\n")
                .compactMap { line -> (String, Bool)? in
                    let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    guard parts.count >= 4,
                          parts[1].hasPrefix("http") else { return nil }
                    return (parts[1], parts[3].lowercased() == "yes")
                }
                .sorted { $0.1 && !$1.1 }
                .map { $0.0 }
                .filter { !$0.isEmpty }

            if !parsed.isEmpty {
                var unique: [String] = []
                var seen = Set<String>()
                for value in parsed where seen.insert(value).inserted {
                    unique.append(value)
                }
                cachedInstances = unique
                return unique
            }
        }

        cachedInstances = fallbackInstances
        return fallbackInstances
    }

    private func isQuarantined(_ base: String) -> Bool {
        guard let until = quarantinedUntil[base] else { return false }
        if until <= Date() {
            quarantinedUntil.removeValue(forKey: base)
            return false
        }
        return true
    }

    private func quarantine(_ base: String) {
        quarantinedUntil[base] = Date().addingTimeInterval(120)
    }

    private func videoID(from value: String?) -> String? {
        guard let value else { return nil }

        if let components = URLComponents(string: value),
           let id = components.queryItems?.first(where: { $0.name == "v" })?.value,
           id.count == 11 {
            return id
        }

        if let range = value.range(of: #"v=([A-Za-z0-9_-]{11})"#, options: .regularExpression) {
            let match = String(value[range])
            return match.replacingOccurrences(of: "v=", with: "")
        }

        return nil
    }

    private func durationMatches(_ value: Double, _ expected: Double) -> Bool {
        guard expected > 0 else { return value > 0 }
        return value > 0 && abs(value - expected) <= 12
    }

    private func titleMatches(_ value: String, _ expected: String) -> Bool {
        let actual = normalized(value)
        let target = normalized(expected)
        return actual == target || actual.contains(target)
    }

    private func isNoise(_ value: String) -> Bool {
        let lower = value.lowercased()
        let blocked = [
            "live", "concert", "karaoke", "tribute", "cover", "remix",
            "bootleg", "reupload", "re-upload", "unofficial", "nightcore",
            "8d audio", "sped up", "slowed", "slowed + reverb", "ai cover",
            "type beat", "instrumental", "reaction", "lyrics video", "fan made"
        ]
        return blocked.contains { lower.contains($0) }
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-zа-яё0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
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
        let collectionType: String?
        let trackCount: Int?
        let artworkUrl100: String?
        let trackTimeMillis: Int?
        let primaryGenreName: String?
        let releaseDate: String?
        let trackExplicitness: String?
    }

    private let noiseTokens = [
        "karaoke", "tribute", "bootleg", "reupload", "re-upload",
        "fan made", "fan-made", "unofficial", "nightcore", "8d audio",
        "sped up", "slowed", "slowed + reverb", "ai cover", "type beat",
        "instrumental cover"
    ]

    func search(_ query: String) async throws -> (tracks: [Track], artists: [Artist]) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ([], []) }

        let audiusTracks = await AudiusService.shared.search(q)
        var tracks: [Track] = audiusTracks.compactMap(AudiusService.shared.makeTrack)
        for country in ["ru", "us", "de"] {
            let url = searchURL(term: q, country: country, entity: "song", limit: 50)
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { continue }
            if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
                tracks.append(contentsOf: decoded.results.compactMap(makeTrack))
            }
            if tracks.count >= 80 { break }
        }

        var artists: [Artist] = []
        for country in ["ru", "us"] {
            let url = searchURL(term: q, country: country, entity: "musicArtist", limit: 15)
            if let (data, response) = try? await session.data(from: url),
               let http = response as? HTTPURLResponse,
               200..<300 ~= http.statusCode,
               let decoded = try? JSONDecoder().decode(Response.self, from: data) {
                artists.append(contentsOf: decoded.results.compactMap(makeArtist))
            }
        }

        let uniqueTracks = Dictionary(grouping: tracks, by: \.id).compactMap { $0.value.first }
        let uniqueArtists = Dictionary(grouping: artists, by: \.id).compactMap { $0.value.first }
        return (rankTracks(Array(uniqueTracks.prefix(80)), query: q), Array(uniqueArtists.prefix(15)))
    }

    func artistTracks(id: Int) async throws -> [Track] {
        var c = URLComponents(string: "https://itunes.apple.com/lookup")!
        c.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "200")
        ]
        let (data, response) = try await session.data(from: c.url!)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw RhythmError.badResponse
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.results.compactMap(makeTrack)
    }

    func artistAlbums(id: Int) async throws -> [Album] {
        var c = URLComponents(string: "https://itunes.apple.com/lookup")!
        c.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "limit", value: "200")
        ]
        let (data, response) = try await session.data(from: c.url!)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw RhythmError.badResponse
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        var seen = Set<Int>()
        return decoded.results.compactMap { item in
            guard let id = item.collectionId,
                  let title = item.collectionName,
                  !isNoise(title),
                  seen.insert(id).inserted else { return nil }
            return Album(
                id: id,
                title: title,
                artist: item.artistName ?? "",
                artistID: item.artistId,
                coverURL: item.artworkUrl100.flatMap(URL.init(string:)),
                releaseDate: item.releaseDate.flatMap(parseDate),
                type: albumType(item.collectionType, trackCount: item.trackCount),
                trackCount: item.trackCount ?? 0
            )
        }.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }

    func albumTracks(id: Int) async throws -> [Track] {
        var c = URLComponents(string: "https://itunes.apple.com/lookup")!
        c.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "200")
        ]
        let (data, response) = try await session.data(from: c.url!)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw RhythmError.badResponse
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.results.compactMap(makeTrack)
    }

    func lyrics(for track: Track) async -> [LyricLine] {
        var c = URLComponents(string: "https://lrclib.net/api/get")!
        c.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album ?? ""),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]

        var request = URLRequest(url: c.url!)
        request.setValue("Rhythm/5.0 (https://github.com/isnoth1ng-prog/-MonetMusic)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else { return [] }

        struct LRC: Decodable {
            let trackName: String?
            let artistName: String?
            let duration: Int?
            let instrumental: Bool?
            let syncedLyrics: String?
            let plainLyrics: String?
        }

        guard let value = try? JSONDecoder().decode(LRC.self, from: data),
              value.instrumental != true,
              lyricMetadataMatches(value.trackName, track.artist, value.artistName, track.title),
              lyricDurationMatches(value.duration, track.duration) else { return [] }

        if let synced = value.syncedLyrics {
            let parsed = parseLRC(synced).filter { isValidLyricLine($0.text) && $0.time <= track.duration + 8 }
            if parsed.count >= 2 { return parsed }
        }

        let plain = (value.plainLyrics ?? "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isValidLyricLine($0) }

        guard plain.count >= 2 else { return [] }
        return plain.enumerated().map { index, line in
            LyricLine(text: line, time: min(Double(index) * 3, max(track.duration - 1, 0)))
        }
    }

    private func lyricMetadataMatches(_ returnedTitle: String?, _ expectedArtist: String, _ returnedArtist: String?, _ expectedTitle: String) -> Bool {
        guard let returnedTitle, let returnedArtist else { return false }
        return normalizedLyric(returnedTitle) == normalizedLyric(expectedTitle)
            && normalizedLyric(returnedArtist) == normalizedLyric(expectedArtist)
    }

    private func lyricDurationMatches(_ returned: Int?, _ expected: Double) -> Bool {
        guard let returned, expected > 0 else { return returned != nil }
        return abs(Double(returned) - expected) <= 6
    }

    private func normalizedLyric(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-zа-яё0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidLyricLine(_ value: String) -> Bool {
        let lower = value.lowercased()
        if value.count < 2 { return false }
        let blocked = ["lyrics:", "music:", "written by", "produced by", "composer:", "songwriter:"]
        return !blocked.contains { lower.hasPrefix($0) }
    }

    func initialWaveTrack(seed: Track?, favorites: [Track], history: [Track]) async -> Track? {
        let seeds = makeSeeds(seed: seed, favorites: favorites, history: history)
        let candidates = await collectWaveCandidates(current: seed, seeds: seeds, playedIDs: Set(seeds.map(\.id)))
        return choose(candidates, current: seed, seeds: seeds, playedIDs: Set(seeds.map(\.id)))
    }

    func nextWaveTrack(current: Track, favorites: [Track], history: [Track], playedIDs: Set<String>) async -> Track? {
        let seeds = makeSeeds(seed: current, favorites: favorites, history: history)
        let candidates = await collectWaveCandidates(current: current, seeds: seeds, playedIDs: playedIDs)
        return choose(candidates, current: current, seeds: seeds, playedIDs: playedIDs)
    }

    private func makeSeeds(seed: Track?, favorites: [Track], history: [Track]) -> [Track] {
        var result: [Track] = []
        if let seed { result.append(seed) }
        result.append(contentsOf: favorites.prefix(8))
        result.append(contentsOf: history.prefix(18))
        var seen = Set<String>()
        return result.filter { seen.insert($0.id).inserted }
    }

    private func collectWaveCandidates(current: Track?, seeds: [Track], playedIDs: Set<String>) async -> [Track] {
        var candidates: [Track] = []

        let queries = [
            current?.artist,
            current?.genre,
            seeds.dropFirst().first?.artist,
            seeds.dropFirst().first?.genre
        ].compactMap { $0 }.filter { !$0.isEmpty }

        for query in queries.prefix(4) {
            if let result = try? await search(query).tracks {
                candidates.append(contentsOf: result)
            }
        }

        if candidates.isEmpty, let result = try? await search("alternative music").tracks {
            candidates = result
        }

        var unique: [String: Track] = [:]
        for track in candidates where !playedIDs.contains(track.id) && !isNoise(track.title) && !isNoise(track.album ?? "") {
            unique[track.id] = track
        }
        return Array(unique.values)
    }

    private func choose(_ candidates: [Track], current: Track?, seeds: [Track], playedIDs: Set<String>) -> Track? {
        guard !candidates.isEmpty else { return nil }
        let history = ListeningStore.shared
        let recentArtists = Set(seeds.prefix(8).map { $0.artist.lowercased() })
        let currentArtist = current?.artist.lowercased()

        let scored = candidates.map { track -> (Track, Double) in
            var score = 0.0
            if let current {
                if track.artist.caseInsensitiveCompare(current.artist) == .orderedSame { score -= 2.5 }
                if track.genre?.caseInsensitiveCompare(current.genre ?? "") == .orderedSame { score += 3.2 }
                if track.albumID == current.albumID { score -= 1.5 }
            }
            if recentArtists.contains(track.artist.lowercased()) { score += 0.5 }
            score += history.preference(for: track.id) * 1.8
            score += Double((track.duration > 150 && track.duration < 420) ? 0.8 : 0)
            score += Double.random(in: -0.65...0.65)

            if track.artist.lowercased() == currentArtist { score -= 2.0 }
            if playedIDs.contains(track.id) { score -= 100 }
            return (track, score)
        }

        return scored.max(by: { $0.1 < $1.1 })?.0
    }

    private func rankTracks(_ tracks: [Track], query: String) -> [Track] {
        let lower = query.lowercased()
        return tracks.sorted {
            let leftExact = $0.title.lowercased() == lower || $0.artist.lowercased() == lower
            let rightExact = $1.title.lowercased() == lower || $1.artist.lowercased() == lower
            if leftExact != rightExact { return leftExact }
            if $0.isExplicit != $1.isExplicit { return !$0.isExplicit }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func isNoise(_ value: String) -> Bool {
        let lower = value.lowercased()
        return noiseTokens.contains { lower.contains($0) }
    }

    private func albumType(_ value: String?, trackCount: Int?) -> Album.AlbumType {
        switch value?.lowercased() {
        case "single": return .single
        case "ep": return .ep
        case "album":
            return (trackCount ?? 99) <= 6 ? .ep : .album
        default:
            return .other
        }
    }

    private func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
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
        guard let id = item.trackId,
              let title = item.trackName,
              let artist = item.artistName,
              !isNoise(title),
              !isNoise(item.collectionName ?? "") else { return nil }

        return Track(
            id: String(id),
            title: title,
            artist: artist,
            artistID: item.artistId,
            album: item.collectionName,
            albumID: item.collectionId,
            coverURL: item.artworkUrl100.flatMap(URL.init(string:)),
            audioURL: nil,
            duration: Double(item.trackTimeMillis ?? 0) / 1000,
            genre: item.primaryGenreName,
            releaseDate: item.releaseDate.flatMap(parseDate),
            isExplicit: item.trackExplicitness == "explicit",
            source: .catalog
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
