import Foundation

@MainActor
@Observable
public final class GitStatusStore {

    private var cache: [String: GitSnapshot] = [:]
    private var scans: [String: Int] = [:]
    private var generations: [String: Int] = [:]
    private var counter = 0
    private var live: Set<String>?
    private var rootByPath: [String: String] = [:]
    private var inFlight: Set<String> = []
    private var pending: Set<String> = []

    public init() {}

    public func status(for session: TerminalSession?) -> GitStatus? {
        guard let snapshot = snapshot(for: session) else { return nil }

        return GitStatus(
            branch: snapshot.branch,
            added: snapshot.added,
            removed: snapshot.removed,
            isDirty: !snapshot.changes.isEmpty,
            tracking: snapshot.tracking
        )
    }

    // Почему: одинаковые счётчики не значат одинаковое дерево, ревью нужна честная ревизия
    public func revision(forRoot root: String?) -> Int {
        root.flatMap { scans[$0] } ?? 0
    }

    // Почему: незавершённый скан живой сессии — не мусор, инвалидируем только ушедшие пути
    public func prune(paths: Set<String>) {
        live = paths

        for path in Set(rootByPath.keys).union(inFlight) where !paths.contains(path) {
            counter += 1
            generations[path] = counter
            pending.remove(path)
        }

        rootByPath = rootByPath.filter { paths.contains($0.key) }

        // Почему: корни живых путей вычисляем сами, иначе чистка выбрасывает свой же снимок
        let alive = Set(rootByPath.values)
        cache = cache.filter { alive.contains($0.key) }
        scans = scans.filter { alive.contains($0.key) }
        generations = generations.filter { inFlight.contains($0.key) }
    }

    public func snapshot(for session: TerminalSession?) -> GitSnapshot? {
        guard let session else { return nil }

        let root = rootByPath[session.url.path(percentEncoded: false)]
        return root.flatMap { cache[$0] }
    }

    // Почему: у добавленной вручную папки нет сессии, читаем её по пути
    public func snapshot(path: String) -> GitSnapshot? {
        rootByPath[path].flatMap { cache[$0] } ?? cache[path]
    }

    public func refresh(path: String) async {
        await refresh(url: URL(filePath: path, directoryHint: .isDirectory))
    }

    public func refresh(_ session: TerminalSession?) async {
        guard let session else { return }

        await refresh(url: session.url)
    }

    public func refresh(url: URL) async {
        let path = url.path(percentEncoded: false)

        guard !inFlight.contains(path) else {
            pending.insert(path)
            return
        }

        inFlight.insert(path)
        defer {
            inFlight.remove(path)
            // Почему: закрытый путь не должен оставлять за собой поколение навсегда
            if live?.contains(path) == false { generations.removeValue(forKey: path) }
        }

        repeat {
            pending.remove(path)
            // Почему: путь могли закрыть, пока шёл предыдущий проход — второй уже не нужен
            guard live?.contains(path) != false else { return }

            let started = generations[path, default: 0]
            await store(GitClient.probe(for: url), at: path, generation: started)
        } while pending.contains(path)
    }

    func store(_ probe: GitClient.Probe, at path: String, generation started: Int) {
        guard generations[path, default: 0] == started else { return }

        switch probe {
        case .notRepository:
            if rootByPath[path] != nil { rootByPath[path] = nil }

        case .failed:
            break

        case let .snapshot(snapshot):
            if rootByPath[path] != snapshot.root { rootByPath[path] = snapshot.root }
            if cache[snapshot.root] != snapshot { cache[snapshot.root] = snapshot }

            scans[snapshot.root, default: 0] += 1
        }
    }
}
