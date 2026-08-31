import Foundation

@MainActor
@Observable
final class GitBranchStore {

    private var cache: [Repository.ID: GitBranchSnapshot] = [:]

    private var operating: Set<Repository.ID> = []

    private var generation: [Repository.ID: Int] = [:]

    private var inFlight: Set<Repository.ID> = []

    private var pending: Set<Repository.ID> = []

    func snapshot(for repository: Repository?) -> GitBranchSnapshot? {
        guard let repository else { return nil }

        return cache[repository.id]
    }

    func isOperating(_ repository: Repository?) -> Bool {
        guard let repository else { return false }

        return operating.contains(repository.id)
    }

    func refresh(_ repository: Repository?) async {
        guard let repository else { return }
        guard !operating.contains(repository.id) else { return }

        guard !inFlight.contains(repository.id) else {
            pending.insert(repository.id)
            return
        }

        inFlight.insert(repository.id)
        defer { inFlight.remove(repository.id) }

        repeat {
            pending.remove(repository.id)
            let generationAtStart = generation[repository.id, default: 0]
            let snapshot = await GitBranchClient.listBranches(for: repository.url)
            let isCurrent = generation[repository.id, default: 0] == generationAtStart

            if isCurrent, cache[repository.id] != snapshot {
                cache[repository.id] = snapshot
            }
        } while pending.contains(repository.id)
    }

    func perform(
        for repository: Repository,
        _ operation: @escaping () async -> GitCommandOutcome
    ) async -> GitCommandOutcome {
        operating.insert(repository.id)
        generation[repository.id, default: 0] += 1

        let outcome = await operation()

        operating.remove(repository.id)
        Task { await refresh(repository) }

        return outcome
    }
}
