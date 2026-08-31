import Foundation

@MainActor
@Observable
final class GitBranchStore {

    private var cache: [String: GitBranchSnapshot] = [:]

    private var rootByPath: [String: String] = [:]

    private var operating: Set<String> = []

    private var generation: [String: Int] = [:]

    private var inFlight: Set<String> = []

    private var pending: Set<String> = []

    func snapshot(for session: TerminalSession?) -> GitBranchSnapshot? {
        guard let session else { return nil }

        let root = rootByPath[session.url.path(percentEncoded: false)]
        return root.flatMap { cache[$0] }
    }

    func isOperating(_ session: TerminalSession?) -> Bool {
        guard let session else { return false }

        return operating.contains(session.url.path(percentEncoded: false))
    }

    func refresh(_ session: TerminalSession?) async {
        guard let session else { return }

        let path = session.url.path(percentEncoded: false)
        guard !operating.contains(path) else { return }

        guard !inFlight.contains(path) else {
            pending.insert(path)
            return
        }

        inFlight.insert(path)
        defer { inFlight.remove(path) }

        repeat {
            pending.remove(path)
            let generationAtStart = generation[path, default: 0]
            let snapshot = await GitBranchClient.listBranches(for: session.url)
            let isCurrent = generation[path, default: 0] == generationAtStart

            if isCurrent {
                rootByPath[path] = snapshot.root
                if let root = snapshot.root, cache[root] != snapshot {
                    cache[root] = snapshot
                }
            }
        } while pending.contains(path)
    }

    func perform(
        for session: TerminalSession,
        _ operation: @escaping () async -> GitCommandOutcome
    ) async -> GitCommandOutcome {
        let path = session.url.path(percentEncoded: false)
        operating.insert(path)
        generation[path, default: 0] += 1

        let outcome = await operation()

        operating.remove(path)
        Task { await refresh(session) }

        return outcome
    }
}
