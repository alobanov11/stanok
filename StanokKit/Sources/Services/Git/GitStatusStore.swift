import Foundation

@MainActor
@Observable
public final class GitStatusStore {

    private var cache: [String: GitSnapshot] = [:]
    private var scans: [String: Int] = [:]
    private var generations: [String: Int] = [:]
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

    // Почему: незавершённый скан не должен вернуть вычищенный репозиторий обратно
    public func prune(roots: Set<String>) {
        for (path, root) in rootByPath where !roots.contains(root) {
            generations[path, default: 0] += 1
        }

        cache = cache.filter { roots.contains($0.key) }
        scans = scans.filter { roots.contains($0.key) }
        rootByPath = rootByPath.filter { roots.contains($0.value) }
    }

    public func snapshot(for session: TerminalSession?) -> GitSnapshot? {
        guard let session else { return nil }

        let root = rootByPath[session.url.path(percentEncoded: false)]
        return root.flatMap { cache[$0] }
    }

    public func refresh(_ session: TerminalSession?) async {
        guard let session else { return }

        let path = session.url.path(percentEncoded: false)

        guard !inFlight.contains(path) else {
            pending.insert(path)
            return
        }

        inFlight.insert(path)
        defer { inFlight.remove(path) }

        repeat {
            pending.remove(path)
            let started = generations[path, default: 0]
            await store(GitClient.probe(for: session.url), at: path, generation: started)
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
