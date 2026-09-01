import Foundation

@MainActor
@Observable
final class BranchCommitStore {

    private enum Limit {

        // Почему: полсотни коммитов читаются за десятки миллисекунд даже на большой истории
        static let commits = 50

        static let freshness: TimeInterval = 60
    }

    private struct Entry {

        let commits: [GitCommitChanges]
        let loadedAt: Date
    }

    private var entries: [String: Entry] = [:]

    @ObservationIgnored
    private var loading: [String: Task<Void, Never>] = [:]

    private static func key(_ root: String, _ branch: String) -> String {
        root + "\n" + branch
    }

    func commits(root: String, branch: String) -> [GitCommitChanges] {
        entries[Self.key(root, branch)]?.commits ?? []
    }

    func commit(root: String, sha: String) -> GitCommitChanges? {
        for (key, entry) in entries where key.hasPrefix(root + "\n") {
            if let found = entry.commits.first(where: { $0.sha == sha }) { return found }
        }

        return nil
    }

    func load(root: String, branch: String) async {
        let key = Self.key(root, branch)

        if let entry = entries[key], Date().timeIntervalSince(entry.loadedAt) < Limit.freshness {
            return
        }

        // Почему: повторное раскрытие ждёт уже идущую загрузку, а не запускает вторую
        if let running = loading[key] {
            await running.value
            return
        }

        let task = Task { [weak self] in
            let found = await GitClient.history(
                of: branch,
                at: URL(filePath: root),
                limit: Limit.commits
            )

            self?.store(found, at: key)
        }

        loading[key] = task
        await task.value
        loading[key] = nil
    }

    func forget(root: String) {
        entries = entries.filter { !$0.key.hasPrefix(root + "\n") }
    }

    private func store(_ commits: [GitCommitChanges], at key: String) {
        entries[key] = Entry(commits: commits, loadedAt: Date())
    }
}
