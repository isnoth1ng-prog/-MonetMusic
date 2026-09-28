import Foundation

final class ITunesMusicService: MusicService {
    
    struct ITunesResponse: Codable {
        let resultCount: Int?
        let results: [ITunesTrack]
    }
    
    struct ITunesTrack: Codable {
        let trackId: Int
        let trackName: String?
        let artistName: String?
        let collectionName: String?
        let artworkUrl100: String?
        let previewUrl: String?
        let trackTimeMillis: Int?
        let primaryGenreName: String?
        let releaseDate: String?
        let trackExplicitness: String?
    }
    
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }
    
    func search(query: String) async throws -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // iTunes storefront availability can vary. Try the requested Russian
        // storefront first, then common fallback storefronts.
        let storefronts = ["ru", "us", "de"]
        var lastError: Error?
        
        for country in storefronts {
            do {
                let tracks = try await search(query: trimmed, country: country)
                if !tracks.isEmpty {
                    return tracks
                }
            } catch {
                lastError = error
            }
        }
        
        if let lastError {
            throw lastError
        }
        return []
    }
    
    private func search(query: String, country: String) async throws -> [Track] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "country", value: country)
        ]
        
        guard let url = components?.url else {
            throw MusicServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MusicServiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MusicServiceError.httpStatus(httpResponse.statusCode)
        }
        
        do {
            let result = try JSONDecoder().decode(ITunesResponse.self, from: data)
            return result.results.compactMap { map(itunesTrack: $0) }
        } catch {
            throw MusicServiceError.decodingError
        }
    }
    
    func getRecommendations(seedTracks: [Track]) async throws -> [Track] {
        guard let seed = seedTracks.randomElement() else { return [] }
        return try await search(query: seed.artist)
    }
    
    func getLyrics(track: Track) async throws -> Lyrics? {
        let cleanTitle = track.title
            .replacingOccurrences(of: "\\([^\\)]+\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = track.artist
        
        guard !cleanTitle.isEmpty, !cleanArtist.isEmpty else { return nil }
        
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: cleanTitle),
            URLQueryItem(name: "artist_name", value: cleanArtist)
        ]
        
        guard let url = components?.url else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            struct LrcResponse: Codable {
                let id: Int
                let syncedLyrics: String?
                let plainLyrics: String?
            }
            
            let results = try JSONDecoder().decode([LrcResponse].self, from: data)
            guard let bestMatch = results.first else { return nil }
            
            if let synced = bestMatch.syncedLyrics, !synced.isEmpty {
                let parsedLines = parseLRC(synced)
                guard !parsedLines.isEmpty else { return nil }
                return Lyrics(id: track.id, trackId: track.id, lines: parsedLines, isSynced: true)
            }
            
            if let plain = bestMatch.plainLyrics, !plain.isEmpty {
                let lines = plain
                    .components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .map { LyricsLine(text: $0, timeStart: 0) }
                return Lyrics(id: track.id, trackId: track.id, lines: lines, isSynced: false)
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    private func parseLRC(_ lrc: String) -> [LyricsLine] {
        var lines: [LyricsLine] = []
        let regex = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2}\\.\\d{2,3})\\](.*)")
        
        for rawLine in lrc.components(separatedBy: .newlines) {
            let range = NSRange(location: 0, length: rawLine.utf16.count)
            guard let match = regex.firstMatch(in: rawLine, options: [], range: range),
                  let minRange = Range(match.range(at: 1), in: rawLine),
                  let secRange = Range(match.range(at: 2), in: rawLine),
                  let textRange = Range(match.range(at: 3), in: rawLine) else {
                continue
            }
            
            let minString = String(rawLine[minRange])
            let secString = String(rawLine[secRange])
            let text = String(rawLine[textRange]).trimmingCharacters(in: .whitespaces)
            
            if let minutes = Double(minString), let seconds = Double(secString), !text.isEmpty {
                lines.append(
                    LyricsLine(
                        text: text,
                        timeStart: (minutes * 60) + seconds
                    )
                )
            }
        }
        
        return lines.sorted {
            ($0.timeStart ?? 0) < ($1.timeStart ?? 0)
        }
    }
    
    private func map(itunesTrack: ITunesTrack) -> Track? {
        guard let title = itunesTrack.trackName,
              let artist = itunesTrack.artistName,
              let audioURLString = itunesTrack.previewUrl,
              let audioURL = URL(string: audioURLString) else {
            return nil
        }
        
        return Track(
            id: String(itunesTrack.trackId),
            title: title,
            artist: artist,
            album: itunesTrack.collectionName,
            coverURL: itunesTrack.artworkUrl100.flatMap(URL.init(string:)),
            audioURL: audioURL,
            duration: Double(itunesTrack.trackTimeMillis ?? 0) / 1000.0,
            genre: itunesTrack.primaryGenreName,
            releaseDate: nil,
            isExplicit: itunesTrack.trackExplicitness == "explicit"
        )
    }
}
