import Foundation

@MainActor
@Observable
final class ReviewCommitStore {

    private var commits: [String: [GitCommitChanges]] = [:]

    @ObservationIgnored
    private var loaded: String?

    @ObservationIgnored
    private var running: Task<Void, Never>?

    func commits(for root: String?) -> [GitCommitChanges] {
        root.flatMap { commits[$0] } ?? []
    }

    // Почему: повторный вызов ждёт идущий проход, иначе очередь git забивается дублями
    func refresh(root: String?, isClean: Bool) async {
        guard let root else { return }

        if let running {
            await running.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }

            await reload(root: root, isClean: isClean)
        }
        running = task
        await task.value
        running = nil
    }

    private func reload(root: String, isClean: Bool) async {
        let url = URL(filePath: root)
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

        loaded = stamp
        commits = [root: found]
    }
}
