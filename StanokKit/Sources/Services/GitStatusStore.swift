import Foundation

@MainActor
@Observable
public final class GitStatusStore {

    private var cache: [Repository.ID: GitStatus] = [:]

    public init() {}

    public func status(for repository: Repository?) -> GitStatus? {
        guard let repository else { return nil }

        return cache[repository.id]
    }

    public func refresh(_ repository: Repository?) async {
        guard let repository else { return }

        cache[repository.id] = await GitClient.status(for: repository.url)
    }
}
