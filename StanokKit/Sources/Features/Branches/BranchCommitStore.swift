import Foundation

@MainActor
@Observable
final class BranchCommitStore {

    // Почему: полсотни коммитов читаются за десятки миллисекунд даже на большой истории
    static let limit = 50

    private var histories: [String: [GitCommitChanges]] = [:]
    private var loading: Set<String> = []

    func commits(for branch: String) -> [GitCommitChanges] {
        histories[branch] ?? []
    }

    func commit(_ sha: String) -> GitCommitChanges? {
        histories.values.lazy.compactMap { $0.first { $0.sha == sha } }.first
    }

    func load(branch: String, root: String) async {
        guard histories[branch] == nil, !loading.contains(branch) else { return }

        loading.insert(branch)
        defer { loading.remove(branch) }

        let found = await GitClient.history(
            of: branch,
            at: URL(filePath: root),
            limit: Self.limit
        )

        guard !Task.isCancelled else { return }

        histories[branch] = found
    }

    func forget(root: String) {
        histories = [:]
    }
}
