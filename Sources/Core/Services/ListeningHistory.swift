import Foundation

struct ListeningEvent: Codable, Hashable {
    let track: Track
    let playedAt: Date
}

final class ListeningHistory {
    static let shared = ListeningHistory()
    private let key = "rhythm.listening.history"
    private let limit = 60

    private init() {}

    func record(_ track: Track) {
        var events = load()
        events.removeAll { $0.track.id == track.id }
        events.insert(ListeningEvent(track: track, playedAt: Date()), at: 0)
        if events.count > limit {
            events = Array(events.prefix(limit))
        }
        save(events)
    }

    func events() -> [ListeningEvent] {
        load()
    }

    func recentTracks(limit: Int = 20) -> [Track] {
        Array(load().prefix(limit).map { $0.track })
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() -> [ListeningEvent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([ListeningEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func save(_ events: [ListeningEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
