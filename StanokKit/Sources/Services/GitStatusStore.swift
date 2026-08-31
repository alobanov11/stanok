import Foundation

@MainActor
@Observable
public final class GitStatusStore {

    private var cache: [Repository.ID: GitSnapshot] = [:]

    private var inFlight: Set<Repository.ID> = []

    private var pending: Set<Repository.ID> = []

    public init() {}

    public func status(for repository: Repository?) -> GitStatus? {
        guard let repository, let snapshot = cache[repository.id] else { return nil }

        return GitStatus(branch: snapshot.branch, added: snapshot.added, removed: snapshot.removed)
    }

    public func snapshot(for repository: Repository?) -> GitSnapshot? {
        guard let repository else { return nil }

        return cache[repository.id]
    }

    public func refresh(_ repository: Repository?) async {
        guard let repository else { return }

        guard !inFlight.contains(repository.id) else {
            pending.insert(repository.id)
            return
        }

        inFlight.insert(repository.id)
        defer { inFlight.remove(repository.id) }

        repeat {
            pending.remove(repository.id)
            let snapshot = await GitClient.snapshot(for: repository.url)
            if cache[repository.id] != snapshot {
                cache[repository.id] = snapshot
            }
        } while pending.contains(repository.id)
    }
}
