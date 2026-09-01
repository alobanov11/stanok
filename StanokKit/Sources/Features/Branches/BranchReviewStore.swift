import Foundation

@MainActor
@Observable
final class BranchReviewStore {

    struct Review: Sendable {

        let changes: [GitChange]
        let commits: [GitCommitChanges]
        let loadedAt: Date
    }

    private enum Limit {

        // Почему: полсотни коммитов читаются за десятки миллисекунд даже на большой истории
        static let commits = 50

        static let freshness: TimeInterval = 60
        static let cached = 24
    }

    private var entries: [String: Review] = [:]

    @ObservationIgnored
    private var loading: [String: Task<Void, Never>] = [:]

    private static func key(_ root: String, _ branch: String) -> String {
        root + "\n" + branch
    }

    func review(root: String, branch: String) -> Review? {
        entries[Self.key(root, branch)]
    }

    func load(root: String, branch: String, isCurrent: Bool) async {
        let key = Self.key(root, branch)

        if let entry = entries[key], Date().timeIntervalSince(entry.loadedAt) < Limit.freshness {
            return
        }

        if let running = loading[key] {
            await running.value
            return
        }

        let task = Task { [weak self] in
            let url = URL(filePath: root)
            // Почему: незакоммиченное есть только у текущей ветки, у остальных читаем историю
            let changes = isCurrent ? await GitClient.changes(at: url) : []
            let commits = await GitClient.history(of: branch, at: url, limit: Limit.commits)

            self?.store(Review(changes: changes, commits: commits, loadedAt: Date()), at: key)
        }

        loading[key] = task
        await task.value
        loading[key] = nil
    }

    func forget(root: String) {
        entries = entries.filter { !$0.key.hasPrefix(root + "\n") }
    }

    private func store(_ review: Review, at key: String) {
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
