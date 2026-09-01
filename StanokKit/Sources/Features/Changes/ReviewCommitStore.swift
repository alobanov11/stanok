import Foundation

@MainActor
@Observable
final class ReviewCommitStore {

    private var commits: [String: [GitCommitChanges]] = [:]

    func commits(for root: String?) -> [GitCommitChanges] {
        root.flatMap { commits[$0] } ?? []
    }

    func refresh(root: String?, isClean: Bool) async {
        guard let root else { return }

        let url = URL(filePath: root)
        guard let head = await GitClient.head(at: url) else { return }

        let base = await ReviewBaselines.shared.base(for: root, head: head, isClean: isClean)
        let found = base == head ? [] : await GitClient.commits(since: base, at: url)
        guard !Task.isCancelled else { return }

        commits[root] = found
    }
}
