import Foundation

@MainActor
@Observable
public final class GitStatusStore {

    private var cache: [Repository.ID: GitStatus] = [:]

    private var inFlight: Set<Repository.ID> = []

    private var pending: Set<Repository.ID> = []

    public init() {}

    public func status(for repository: Repository?) -> GitStatus? {
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
            let status = await GitClient.status(for: repository.url)
            if cache[repository.id] != status {
                cache[repository.id] = status
            }
        } while pending.contains(repository.id)
    }
}
