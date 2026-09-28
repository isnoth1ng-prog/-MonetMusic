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
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&entity=song&limit=30&country=ru") else {
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
        // Clean title for better matching (remove text in parentheses like "(feat. X)")
        let cleanTitle = track.title.replacingOccurrences(of: "\\([^\\)]+\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        
        guard let encodedArtist = track.artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.lyrics.ovh/v1/\(encodedArtist)/\(encodedTitle)") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            struct LyricsResponse: Codable {
                let lyrics: String
            }
            
            let result = try JSONDecoder().decode(LyricsResponse.self, from: data)
            let rawLines = result.lyrics.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Skip the first line if it's the "Paroles de la chanson" attribution
            let linesToUse = rawLines.first?.contains("Paroles de") == true ? Array(rawLines.dropFirst()) : rawLines
            
            let lines = linesToUse.map { LyricsLine(text: $0, timeStart: 0) }
            return Lyrics(id: track.id, trackId: track.id, lines: lines, isSynced: false)
        } catch {
            return nil
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
