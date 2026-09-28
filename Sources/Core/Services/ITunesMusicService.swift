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
        let cleanTitle = track.title
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\[[^]]*\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?track_name=\(encodedTitle)&artist_name=\(encodedArtist)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        struct LrcResponse: Codable {
            let id: Int
            let trackName: String?
            let artistName: String?
            let albumName: String?
            let duration: Double?
            let syncedLyrics: String?
            let plainLyrics: String?
        }
        
        let results = try JSONDecoder().decode([LrcResponse].self, from: data)
        guard !results.isEmpty else { return nil }
        
        // Prefer exact artist/title matches and lyrics with synchronization.
        // LRCLIB can return remixes, covers and alternate versions first.
        let normalizedTitle = normalizeForMatch(cleanTitle)
        let normalizedArtist = normalizeForMatch(cleanArtist)
        let targetDuration = track.duration
        
        let best = results.max { lhs, rhs in
            lyricsScore(lhs, title: normalizedTitle, artist: normalizedArtist, duration: targetDuration)
                < lyricsScore(rhs, title: normalizedTitle, artist: normalizedArtist, duration: targetDuration)
        }
        
        guard let match = best else { return nil }
        
        if let synced = match.syncedLyrics, !synced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let parsed = parseLRC(synced)
            if !parsed.isEmpty {
                return Lyrics(id: track.id, trackId: track.id, lines: parsed, isSynced: true)
            }
        }
        
        if let plain = match.plainLyrics, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = plain
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { LyricsLine(text: $0, timeStart: nil) }
            if !lines.isEmpty {
                return Lyrics(id: track.id, trackId: track.id, lines: lines, isSynced: false)
            }
        }
        
        return nil
    }
    
    private func normalizeForMatch(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-zA-Zа-яА-Я0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func lyricsScore<T>(_ item: T, title: String, artist: String, duration: Double) -> Double where T: Codable {
        guard let item = item as? Any else { return 0 }
        let mirror = Mirror(reflecting: item)
        func value(_ key: String) -> String? {
            mirror.children.first(where: { $0.label == key })?.value as? String
        }
        func doubleValue(_ key: String) -> Double? {
            mirror.children.first(where: { $0.label == key })?.value as? Double
        }
        
        var score = 0.0
        if let itemTitle = value("trackName"), normalizeForMatch(itemTitle) == title { score += 5 }
        if let itemArtist = value("artistName"), normalizeForMatch(itemArtist) == artist { score += 5 }
        if value("syncedLyrics")?.isEmpty == false { score += 4 }
        if let itemDuration = doubleValue("duration"), duration > 0 {
            let delta = abs(itemDuration - duration)
            if delta < 3 { score += 3 }
            else if delta < 10 { score += 1 }
        }
        return score
    }
    
    private func parseLRC(_ lrc: String) -> [LyricsLine] {
        // A single LRC line may contain multiple timestamps. Expand every
        // timestamp into its own timed lyric line so sync remains accurate.
        let regex = try! NSRegularExpression(
            pattern: #"\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]"#
        )
        var lines: [LyricsLine] = []
        
        for rawLine in lrc.components(separatedBy: .newlines) {
            let nsRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            let matches = regex.matches(in: rawLine, options: [], range: nsRange)
            guard !matches.isEmpty else { continue }
            
            let textRange = rawLine.rangeOfCharacter(from: .punctuationCharacters)
            _ = textRange // Keep parsing independent of punctuation in the lyric.
            
            let lyricText: String = {
                if let first = matches.first,
                   let range = Range(first.range, in: rawLine) {
                    return String(rawLine[range.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }()
            
            guard !lyricText.isEmpty else { continue }
            
            for match in matches {
                guard let minuteRange = Range(match.range(at: 1), in: rawLine),
                      let secondRange = Range(match.range(at: 2), in: rawLine),
                      let minute = Double(rawLine[minuteRange]),
                      let second = Double(rawLine[secondRange]) else { continue }
                
                var fractional = 0.0
                if match.range(at: 3).location != NSNotFound,
                   let fractionRange = Range(match.range(at: 3), in: rawLine) {
                    let fraction = String(rawLine[fractionRange])
                    fractional = Double("0.\(fraction)") ?? 0
                }
                
                lines.append(
                    LyricsLine(
                        text: lyricText,
                        timeStart: minute * 60 + second + fractional
                    )
                )
            }
        }
        
        return lines
            .sorted { ($0.timeStart ?? 0) < ($1.timeStart ?? 0) }
            .reduce(into: []) { result, line in
                if result.last?.text != line.text || result.last?.timeStart != line.timeStart {
                    result.append(line)
                }
            }
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
