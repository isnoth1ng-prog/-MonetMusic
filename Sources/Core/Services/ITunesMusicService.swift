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
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&entity=song&limit=30") else {
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
        // Using a public Lyrics API (lyrics.ovh) as a fallback
        // Since it's often unreliable, we'll mock some lyrics if it fails or just mock them entirely for the prototype.
        // For a true premium feel without breaking when APIs fail, we generate mocked lyrics.
        
        let mockedLines = [
            LyricsLine(text: "Music playing...", timeStart: 0),
            LyricsLine(text: "Enjoying the rhythm of \(track.title)", timeStart: 5),
            LyricsLine(text: "By \(track.artist)", timeStart: 10),
            LyricsLine(text: "In the album \(track.album ?? "Unknown")", timeStart: 15),
            LyricsLine(text: "Let the beat drop", timeStart: 20),
            LyricsLine(text: "Feeling the Monet aesthetic", timeStart: 25)
        ]
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return Lyrics(id: UUID().uuidString, trackId: track.id, lines: mockedLines, isSynced: true)
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
