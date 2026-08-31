import Foundation

@MainActor
@Observable
public final class GitStatusStore {

    private var cache: [String: GitSnapshot] = [:]
    private var rootByPath: [String: String] = [:]
    private var inFlight: Set<String> = []
    private var pending: Set<String> = []

    public init() {}

    public func status(for session: TerminalSession?) -> GitStatus? {
        guard let snapshot = snapshot(for: session) else { return nil }

        return GitStatus(branch: snapshot.branch, added: snapshot.added, removed: snapshot.removed)
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
            let snapshot = await GitClient.snapshot(for: session.url)
            rootByPath[path] = snapshot?.root
            if let root = snapshot?.root, cache[root] != snapshot {
                cache[root] = snapshot
            }
        } while pending.contains(path)
    }
}
