import Foundation

@MainActor
@Observable
final class BranchReviewStore {

    struct Review: Sendable {

        let changes: [GitChange]
        let commits: [GitCommitChanges]
        let loadedAt: Date

        var isStale = false
    }

    private enum Limit {

        // Почему: полсотни коммитов читаются за десятки миллисекунд даже на большой истории
        static let commits = 50

        static let freshness: TimeInterval = 60
        static let cached = 24
    }

    private var entries: [String: Review] = [:]

    @ObservationIgnored
    private var generations: [String: Int] = [:]

    @ObservationIgnored
    private var running: [String: Int] = [:]

    @ObservationIgnored
    private var loading: [String: Task<Void, Never>] = [:]

    private static func key(_ root: String, _ branch: String, _ isCurrent: Bool) -> String {
        root + "\n" + branch + "\n" + (isCurrent ? "current" : "other")
    }

    func review(root: String, branch: String, isCurrent: Bool) -> Review? {
        entries[Self.key(root, branch, isCurrent)]
    }

    func load(root: String, branch: String, isCurrent: Bool) async {
        let key = Self.key(root, branch, isCurrent)

        let started = generations[key, default: 0]

        guard needsLoad(key) else { return }

        // Почему: ждать имеет смысл только загрузку своего поколения, старую — нет
        if let task = loading[key], running[key] == started {
            await task.value
            return
        }

        let task = Task { [weak self] in
            let url = URL(filePath: root)
            // Почему: незакоммиченное есть только у текущей ветки, у остальных читаем историю
            let changes = isCurrent ? await GitClient.workingChanges(at: url) : []
            let commits = await GitClient.history(of: branch, at: url, limit: Limit.commits)

            guard let changes, let commits else { return }

            self?.store(
                Review(changes: changes, commits: commits, loadedAt: Date()),
                at: key,
                generation: started
            )
        }

        loading[key] = task
        running[key] = started
        await task.value

        if running[key] == started {
            loading[key] = nil
            running[key] = nil
        }
    }

    // Почему: показанное ревью держится до успешной замены, иначе панель мигает пустотой
    func forget(root: String) {
        for key in entries.keys where key.hasPrefix(root + "\n") {
            generations[key, default: 0] += 1
            entries[key]?.isStale = true
        }
    }

    private func needsLoad(_ key: String) -> Bool {
        guard let entry = entries[key], !entry.isStale else { return true }

        return Date().timeIntervalSince(entry.loadedAt) >= Limit.freshness
    }

    private func store(_ review: Review, at key: String, generation started: Int) {
        guard generations[key, default: 0] == started else { return }

        entries[key] = review

        guard entries.count > Limit.cached else { return }

        let stale = entries.sorted { $0.value.loadedAt < $1.value.loadedAt }
            .prefix(entries.count - Limit.cached)
            .map(\.key)

        for key in stale {
            entries.removeValue(forKey: key)
        }
    }
}
