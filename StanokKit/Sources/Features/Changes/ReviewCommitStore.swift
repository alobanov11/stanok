import Foundation

@MainActor
@Observable
final class ReviewCommitStore {

    private var commits: [String: [GitCommitChanges]] = [:]

    @ObservationIgnored
    private var loaded: String?

    @ObservationIgnored
    private var running: Task<Void, Never>?

    @ObservationIgnored
    private var pending: (root: String, isClean: Bool)?

    func commits(for root: String?) -> [GitCommitChanges] {
        root.flatMap { commits[$0] } ?? []
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
        let found = base == head ? [] : await GitClient.commits(since: base, upTo: head, at: url)

        loaded = stamp
        commits = [root: found]
    }
}
