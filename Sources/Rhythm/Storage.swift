import Foundation

@MainActor
final class ListeningStore: ObservableObject {
    static let shared = ListeningStore()
    @Published private(set) var favorites: [Track] = []
    @Published private(set) var history: [Track] = []

    private let favoritesKey = "rhythm.favorites"
    private let historyKey = "rhythm.history"
    private let profileKey = "rhythm.listening.profile"
    private var profile: [String: Double] = [:]

    private init() { load() }

    func toggleLike(_ track: Track) {
        if favorites.contains(where: { $0.id == track.id }) {
            favorites.removeAll { $0.id == track.id }
        } else {
            favorites.insert(track, at: 0)
        }
        save()
    }

    func isLiked(_ id: String) -> Bool { favorites.contains { $0.id == id } }

    func record(_ track: Track) {
        history.removeAll { $0.id == track.id }
        history.insert(track, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
        save()
    }

    func noteListening(trackID: String, ratio: Double, liked: Bool = false) {
        let r = max(0, min(ratio, 1))
        let delta: Double
        if liked { delta = 2.0 }
        else if r >= 0.85 { delta = 1.25 }
        else if r >= 0.55 { delta = 0.45 }
        else if r < 0.20 { delta = -1.1 }
        else { delta = -0.15 }
        profile[trackID, default: 0] += delta
        profile[trackID] = max(-6, min(profile[trackID]!, 8))
        save()
    }

    func preference(for id: String) -> Double { profile[id] ?? 0 }

    func clearHistory() {
        history.removeAll()
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(favorites) { UserDefaults.standard.set(d, forKey: favoritesKey) }
        if let d = try? JSONEncoder().encode(history) { UserDefaults.standard.set(d, forKey: historyKey) }
        UserDefaults.standard.set(profile, forKey: profileKey)
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: favoritesKey), let v = try? JSONDecoder().decode([Track].self, from: d) { favorites = v }
        if let d = UserDefaults.standard.data(forKey: historyKey), let v = try? JSONDecoder().decode([Track].self, from: d) { history = v }
        profile = (UserDefaults.standard.dictionary(forKey: profileKey) as? [String: Double]) ?? [:]
    }
}
