import Foundation

@MainActor
@Observable
public final class AgentChangesModel {

    public private(set) var repositories: [AgentRepositoryChanges] = []

    public private(set) var isLoading = false

    public private(set) var checkedAt: Date?

    @ObservationIgnored
    private var source: (any AgentTouchesSource)?

    @ObservationIgnored
    private var refreshing: Task<Void, Never>?

    public nonisolated init() {}

    public func use(_ source: any AgentTouchesSource) {
        self.source = source
    }

    public func refresh() {
        guard refreshing == nil else { return }

        isLoading = true
        refreshing = Task { [weak self] in
            await self?.reload()
            self?.refreshing = nil
        }
    }
}

private extension AgentChangesModel {

    func reload() async {
        defer { isLoading = false }

        guard let source else { return }

        let touched = await source.touched()
        var roots: [String: Date] = [:]
        var byRoot: [String: [AgentTouchedFile]] = [:]

        for directory in touched.directories {
            guard let root = await GitClient.root(for: URL(filePath: directory)) else { continue }

            roots[root] = roots[root] ?? .distantPast
        }

        for file in touched.files {
            let directory = file.url.deletingLastPathComponent()
            guard let root = await GitClient.root(for: directory) else { continue }

            byRoot[root, default: []].append(file)
            roots[root] = max(roots[root] ?? .distantPast, file.touchedAt)
        }

        var found: [AgentRepositoryChanges] = []
        for (root, touchedAt) in roots {
            let changes = await changes(at: root)
            let changed = Set(changes.map { root + "/" + $0.path })
            let untouched = (byRoot[root] ?? [])
                .filter { !changed.contains($0.url.path(percentEncoded: false)) }
                .sorted { $0.touchedAt > $1.touchedAt }

            guard !changes.isEmpty || !untouched.isEmpty else { continue }

            found.append(AgentRepositoryChanges(
                root: root,
                changes: changes,
                touchedOnly: untouched,
                touchedAt: touchedAt
            ))
        }

        repositories = found.sorted { $0.touchedAt > $1.touchedAt }
        checkedAt = Date()
    }

    func changes(at root: String) async -> [GitChange] {
        guard case let .snapshot(snapshot) = await GitClient.probe(for: URL(filePath: root))
        else { return [] }

        return snapshot.changes
    }
}
