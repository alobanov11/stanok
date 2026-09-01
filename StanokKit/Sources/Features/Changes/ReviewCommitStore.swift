import Foundation

@MainActor
@Observable
final class ReviewCommitStore {

    private var commits: [String: [GitCommitChanges]] = [:]

    @ObservationIgnored
    private var loaded: String?

    @ObservationIgnored
    private var token = UUID()

    func commits(for root: String?) -> [GitCommitChanges] {
        root.flatMap { commits[$0] } ?? []
    }

    func refresh(root: String?, isClean: Bool) async {
        guard let root else { return }

        let url = URL(filePath: root)
        let generation = UUID()
        token = generation

        guard let head = await GitClient.head(at: url) else { return }

        // Почему: без ключа состояния историю перечитывал каждый чих файловой системы
        let stamp = [root, head, "\(isClean)"].joined(separator: "|")
        guard stamp != loaded else { return }

        let parent = await GitClient.parent(at: url)
        let base = await ReviewBaselines.shared.base(
            for: root,
            head: head,
            parent: parent,
            isClean: isClean
        )
        let found = base == head ? [] : await GitClient.commits(since: base, upTo: head, at: url)
        guard !Task.isCancelled, token == generation else { return }

        loaded = stamp
        commits = [root: found]
    }
}
