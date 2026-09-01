import Foundation

@MainActor
@Observable
final class ReviewCommitStore {

    private var commits: [String: [GitCommitChanges]] = [:]

    @ObservationIgnored
    private var loaded: String?

    @ObservationIgnored
    private var loadedRoot: String?

    @ObservationIgnored
    private var running: Task<Void, Never>?

    @ObservationIgnored
    private var pending: (root: String, isClean: Bool)?

    // Почему: пока не пересчитали, история другого репозитория — не наша правда
    func commits(for root: String?) -> [GitCommitChanges] {
        guard let root, root == loadedRoot else { return [] }

        return commits[root] ?? []
    }

    // Почему: повторный вызов ждёт идущий проход, иначе очередь git забивается дублями
    func refresh(root: String?, isClean: Bool) async {
        guard let root else { return }

        if let running {
            pending = (root, isClean)
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

        // Почему: пока шёл проход, состояние могло смениться — доводим до актуального
        if let next = pending {
            pending = nil
            await refresh(root: next.root, isClean: next.isClean)
        }
    }

    private func reload(root: String, isClean: Bool) async {
        let url = URL(filePath: root)
        guard let head = await GitClient.head(at: url) else { return }

        let parent = await GitClient.parent(at: url)
        let base = await ReviewBaselines.shared.base(
            for: root,
            head: head,
            parent: parent,
            isClean: isClean
        )

        // Почему: точка отсчёта могла сдвинуться сама, поэтому ключ считаем уже с ней
        let stamp = [root, head, base, "\(isClean)"].joined(separator: "|")
        guard stamp != loaded else { return }
        // Почему: сбой git — это не «коммитов нет», такой ответ кэшировать нельзя
        guard
            let found = base == head
            ? []
            : await GitClient.commits(since: base, upTo: head, at: url)
        else { return }

        loaded = stamp
        loadedRoot = root
        commits = [root: found]
    }
}
