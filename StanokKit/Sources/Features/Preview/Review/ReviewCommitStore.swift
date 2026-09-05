import Foundation

@MainActor
@Observable
final class ReviewCommitStore {

    private var commits: [String: [GitCommitChanges]] = [:]

    @ObservationIgnored
    private var stamps: [String: String] = [:]

    @ObservationIgnored
    private var running: [String: Task<Void, Never>] = [:]

    @ObservationIgnored
    private var pending: [String: (branch: String?, isClean: Bool)] = [:]

    // Почему: ревью собирается по всем репозиториям инспектора, а не по одному активному
    func commits(for root: String?) -> [GitCommitChanges] {
        guard let root else { return [] }

        return commits[root] ?? []
    }

    func prune(roots: Set<String>) {
        commits = commits.filter { roots.contains($0.key) }
        stamps = stamps.filter { roots.contains($0.key) }
    }

    // Почему: повторный вызов ждёт идущий проход, иначе очередь git забивается дублями
    func refresh(root: String?, branch: String?, isClean: Bool) async {
        guard let root else { return }

        if let task = running[root] {
            pending[root] = (branch, isClean)
            await task.value
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }

            await reload(root: root, branch: branch, isClean: isClean)
        }
        running[root] = task
        await task.value
        running[root] = nil

        // Почему: пока шёл проход, состояние могло смениться — доводим до актуального
        if let next = pending.removeValue(forKey: root) {
            await refresh(root: root, branch: next.branch, isClean: next.isClean)
        }
    }

    private func loadRoot(root: String, head: String, isClean: Bool, url: URL) async {
        let stamp = [root, head, "root", "\(isClean)"].joined(separator: "|")
        guard stamp != stamps[root], let found = await GitClient.history(of: head, at: url, limit: 1)
        else { return }

        stamps[root] = stamp
        commits[root] = found
    }

    private func reload(root: String, branch: String?, isClean: Bool) async {
        let url = URL(filePath: root)
        guard let head = await GitClient.head(at: url) else { return }

        // Почему: сбой git не должен сдвинуть точку отсчёта на текущий коммит
        guard let parent = await GitClient.parent(at: url) else { return }

        // Почему: у корневого коммита нет предка, но читать его всё равно нужно
        guard parent != nil else {
            await loadRoot(root: root, head: head, isClean: isClean, url: url)
            return
        }
        let base = await ReviewBaselines.shared.base(
            for: root,
            head: head,
            parent: parent,
            branch: branch,
            isClean: isClean
        )

        // Почему: точка отсчёта могла сдвинуться сама, поэтому ключ считаем уже с ней
        let stamp = [root, head, base, "\(isClean)"].joined(separator: "|")
        guard stamp != stamps[root] else { return }
        // Почему: сбой git — это не «коммитов нет», такой ответ кэшировать нельзя
        guard
            let found = base == head
            ? []
            : await GitClient.commits(since: base, upTo: head, at: url)
        else { return }

        stamps[root] = stamp
        commits[root] = found
    }
}
