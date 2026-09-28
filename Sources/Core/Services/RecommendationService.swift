import Foundation

final class RecommendationService {
    private let musicService: MusicService

    init(musicService: MusicService = ITunesMusicService()) {
        self.musicService = musicService
    }

    func makeWave(liked: [Track], mood: String? = nil) async throws -> [Track] {
        let recent = ListeningHistory.shared.recentTracks(limit: 24)
        let seeds = uniqueTracks(liked + recent)

        var queries: [String] = []
        let topArtists = weightedArtists(liked: liked, recent: recent)
        let topGenres = weightedGenres(seeds)

        if let moodQuery = moodQuery(mood), !moodQuery.isEmpty {
            if let artist = topArtists.first {
                queries.append("\(moodQuery) \(artist)")
            } else {
                queries.append(moodQuery)
            }
        }

        queries.append(contentsOf: topArtists.prefix(2))
        queries.append(contentsOf: topGenres.prefix(1))

        if queries.isEmpty {
            queries = ["русский рэп", "хип хоп"]
        }

        let cappedQueries = Array(NSOrderedSet(array: queries)) as? [String] ?? queries

        return await fetchAndRank(
            queries: Array(cappedQueries.prefix(3)),
            seeds: seeds
        )
    }

    func homeRecommendations(liked: [Track]) async -> [Track] {
        let recent = ListeningHistory.shared.recentTracks(limit: 12)
        let seeds = uniqueTracks(liked + recent)
        let artists = weightedArtists(liked: liked, recent: recent)
        let genres = weightedGenres(seeds)

        var queries = Array(artists.prefix(2))
        if let genre = genres.first { queries.append(genre) }
        if queries.isEmpty { queries = ["русский рэп", "новая музыка"] }

        return await fetchAndRank(queries: Array(queries.prefix(3)), seeds: seeds)
    }

    private func fetchAndRank(queries: [String], seeds: [Track]) async -> [Track] {
        guard !queries.isEmpty else { return [] }

        var found: [Track] = []
        await withTaskGroup(of: [Track].self) { group in
            for query in queries {
                group.addTask {
                    (try? await self.musicService.search(query: query)) ?? []
                }
            }
            for await tracks in group {
                found.append(contentsOf: tracks)
            }
        }

        let seedIDs = Set(seeds.map { $0.id })
        var unique: [Track] = []
        var seen = Set<String>()

        for track in found {
            guard !seedIDs.contains(track.id), seen.insert(track.id).inserted else { continue }
            unique.append(track)
        }

        let artistWeights = Dictionary(
            weightedArtists(liked: seeds, recent: []).enumerated().map { ($0.element, 3.0 / Double($0.offset + 1)) },
            uniquingKeysWith: max
        )
        let genreWeights = Dictionary(
            weightedGenres(seeds).enumerated().map { ($0.element, 2.0 / Double($0.offset + 1)) },
            uniquingKeysWith: max
        )

        return unique.sorted {
            score($0, artistWeights: artistWeights, genreWeights: genreWeights) >
            score($1, artistWeights: artistWeights, genreWeights: genreWeights)
        }
    }

    private func score(_ track: Track, artistWeights: [String: Double], genreWeights: [String: Double]) -> Double {
        let artist = artistWeights[track.artist, default: 0]
        let genre = genreWeights[track.genre ?? "", default: 0]
        return artist * 4 + genre * 2 + Double.random(in: 0...0.5)
    }

    private func weightedArtists(liked: [Track], recent: [Track]) -> [String] {
        var weights: [String: Double] = [:]
        liked.forEach { weights[$0.artist, default: 0] += 4 }
        recent.enumerated().forEach { index, track in
            weights[track.artist, default: 0] += max(1, 3 - Double(index) * 0.12)
        }
        return weights.sorted { $0.value > $1.value }.map { $0.key }
    }

    private func weightedGenres(_ tracks: [Track]) -> [String] {
        var weights: [String: Double] = [:]
        tracks.compactMap { $0.genre }.forEach { weights[$0, default: 0] += 1 }
        return weights.sorted { $0.value > $1.value }.map { $0.key }
    }

    private func moodQuery(_ mood: String?) -> String? {
        switch mood {
        case "Бодрое": return "энергичный рэп"
        case "Грустное": return "грустный рэп"
        case "Спокойное": return "lofi chill"
        case "Для тренировки": return "workout hip hop"
        default: return nil
        }
    }

    private func uniqueTracks(_ tracks: [Track]) -> [Track] {
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }
}
