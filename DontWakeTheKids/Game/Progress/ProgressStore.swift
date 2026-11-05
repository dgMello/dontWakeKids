import Foundation

/// What the player has done in one level.
struct LevelProgress: Codable, Equatable {
    var cleared = false
    var bestStars = 0
    var bestScore = 0
    var collectibles: Set<String> = []
    var nightModeUnlocked = false
}

/// Saves per-level progress as JSON in UserDefaults.
@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    private static let key = "progress.v1"
    /// The single best score saved before levels existed.
    private static let legacyBestScoreKey = "bestScore"

    @Published private(set) var levels: [LevelID: LevelProgress] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: LevelProgress].self, from: data) {
            for (key, value) in saved {
                if let id = LevelID(rawValue: key) { levels[id] = value }
            }
        } else {
            let legacy = defaults.integer(forKey: Self.legacyBestScoreKey)
            if legacy > 0 {
                levels[.classicMorning] = LevelProgress(cleared: true, bestScore: legacy)
                save()
            }
        }
    }

    func progress(for id: LevelID) -> LevelProgress {
        levels[id] ?? LevelProgress()
    }

    /// A level is open if it's the first one, or the one before it was cleared.
    func isUnlocked(_ id: LevelID) -> Bool {
        let order = LevelDefinition.all.map(\.id)
        guard let index = order.firstIndex(of: id) else { return false }
        if index == 0 { return true }
        return progress(for: order[index - 1]).cleared
    }

    /// Records a win. Returns true if the score beat the previous best.
    @discardableResult
    func recordWin(_ id: LevelID, stars: Int, score: Int) -> Bool {
        var p = progress(for: id)
        let isNewBest = score > p.bestScore
        p.cleared = true
        p.bestStars = max(p.bestStars, stars)
        p.bestScore = max(p.bestScore, score)
        levels[id] = p
        save()
        return isNewBest
    }

    func reset() {
        levels = [:]
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.legacyBestScoreKey)
    }

    private func save() {
        let encodable = Dictionary(uniqueKeysWithValues: levels.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encodable) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
