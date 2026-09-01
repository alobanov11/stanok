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

        return operating.contains(key(for: session))
    }

    func key(for session: TerminalSession) -> String {
        let path = session.url.path(percentEncoded: false)

        return rootByPath[path] ?? path
    }

    func refresh(_ session: TerminalSession?) async {
        guard let session else { return }

        let path = session.url.path(percentEncoded: false)
        guard !operating.contains(key(for: session)) else { return }

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

            store(snapshot, at: path, generation: generationAtStart)
        } while pending.contains(path)
    }

    func store(_ snapshot: GitBranchSnapshot, at path: String, generation generationAtStart: Int) {
        guard generation[path, default: 0] == generationAtStart else { return }

        let key = snapshot.root ?? path

        if rootByPath[path] != key { rootByPath[path] = key }
        if cache[key] != snapshot { cache[key] = snapshot }
    }

    func perform(
        for session: TerminalSession,
        _ operation: @escaping () async -> GitCommandOutcome
    ) async -> GitCommandOutcome {
        let path = session.url.path(percentEncoded: false)
        let scope = key(for: session)
        guard operating.insert(scope).inserted else {
            return GitCommandOutcome(succeeded: false, message: "Операция уже выполняется")
        }

        generation[path, default: 0] += 1

        let outcome = await operation()

        operating.remove(scope)
        Task { await refresh(session) }

        return outcome
    }
}
