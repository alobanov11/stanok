import Foundation

@MainActor
@Observable
final class LastCommitStore {

    private var commits: [String: GitCommitChanges] = [:]

    func commit(for root: String?) -> GitCommitChanges? {
        root.flatMap { commits[$0] }
    }

    func refresh(root: String?, isClean: Bool) async {
        guard let root, isClean else { return }

        let commit = await GitClient.lastCommit(at: URL(filePath: root))
        guard !Task.isCancelled, let commit else { return }

        commits[root] = commit
    }
}
