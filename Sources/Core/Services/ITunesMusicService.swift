import Foundation

class ITunesMusicService: MusicService {
    
    struct ITunesResponse: Codable {
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
    
    func search(query: String) async throws -> [Track] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&entity=song&limit=200&country=ru") else {
            throw MusicServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw MusicServiceError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(ITunesResponse.self, from: data)
        
        return result.results.compactMap { map(itunesTrack: $0) }
    }
    
    func getRecommendations(seedTracks: [Track]) async throws -> [Track] {
        // iTunes API doesn't have a direct recommendation endpoint.
        // We'll simulate recommendations by searching for tracks from the same artist or genre of a seed track.
        guard let seed = seedTracks.randomElement() else { return [] }
        return try await search(query: seed.artist)
    }
    
    func getLyrics(track: Track) async throws -> Lyrics? {
        let cleanTitle = track.title.replacingOccurrences(of: "\\([^\\)]+\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        let cleanArtist = track.artist
        
        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?track_name=\(encodedTitle)&artist_name=\(encodedArtist)") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            struct LrcResponse: Codable {
                let id: Int
                let syncedLyrics: String?
                let plainLyrics: String?
            }
            
            let results = try JSONDecoder().decode([LrcResponse].self, from: data)
            guard let bestMatch = results.first else { return nil }
            
            if let synced = bestMatch.syncedLyrics, !synced.isEmpty {
                let parsedLines = parseLRC(synced)
                return Lyrics(id: track.id, trackId: track.id, lines: parsedLines, isSynced: true)
            } else if let plain = bestMatch.plainLyrics, !plain.isEmpty {
                let lines = plain.components(separatedBy: "\n").filter { !$0.isEmpty }.map { LyricsLine(text: $0, timeStart: 0) }
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
        
        let rawLines = lrc.components(separatedBy: "\n")
        for line in rawLines {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                if let minRange = Range(match.range(at: 1), in: line),
                   let secRange = Range(match.range(at: 2), in: line),
                   let textRange = Range(match.range(at: 3), in: line) {
                    
                    let minStr = String(line[minRange])
                    let secStr = String(line[secRange])
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                    
                    if let min = Double(minStr), let sec = Double(secStr) {
                        let totalSeconds = (min * 60) + sec
                        lines.append(LyricsLine(text: text, timeStart: totalSeconds))
                    }
                }
            }
        }
        return lines.isEmpty ? lrc.components(separatedBy: "\n").map { LyricsLine(text: $0, timeStart: 0) } : lines
    }
    
    private func map(itunesTrack: ITunesTrack) -> Track? {
        guard let id = itunesTrack.trackId.description.isEmpty ? nil : itunesTrack.trackId.description,
              let title = itunesTrack.trackName,
              let artist = itunesTrack.artistName,
              let audioURLString = itunesTrack.previewUrl,
              let audioURL = URL(string: audioURLString) else {
            return nil
        }
        
        return Track(
            id: id,
            title: title,
            artist: artist,
            album: itunesTrack.collectionName,
            coverURL: itunesTrack.artworkUrl100.flatMap { URL(string: $0) },
            audioURL: audioURL,
            duration: Double(itunesTrack.trackTimeMillis ?? 30000) / 1000.0,
            genre: itunesTrack.primaryGenreName,
            releaseDate: nil, // Parse if needed
            isExplicit: itunesTrack.trackExplicitness == "explicit"
        )
    }
}
