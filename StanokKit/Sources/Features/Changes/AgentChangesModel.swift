import Foundation

@MainActor
@Observable
public final class AgentChangesModel {

    private enum Limit {

        static let touchedPerRepository = 60
    }

    public private(set) var repositories: [AgentRepositoryChanges] = []

    public private(set) var isLoading = false

    public private(set) var checkedAt: Date?

    @ObservationIgnored
    private var source: (any AgentTouchesSource)?

    public nonisolated init() {}

    public func use(_ source: any AgentTouchesSource) {
        self.source = source
    }

    public func refresh() async {
        isLoading = true
        await reload()
    }
}

private extension AgentChangesModel {

    func reload() async {
        defer { isLoading = false }

        guard let source else { return }

        let touched = await source.touched()
        guard !Task.isCancelled else { return }

        var roots: [String: Date] = [:]
        var byRoot: [String: [AgentTouchedFile]] = [:]
        var knownRoots: [String: String?] = [:]

        for directory in touched.directories.sorted() {
            guard !Task.isCancelled else { return }
            guard let root = await root(of: directory, known: &knownRoots) else { continue }

            roots[root] = roots[root] ?? .distantPast
        }

        for file in touched.files {
            guard !Task.isCancelled else { return }

            let directory = file.url.deletingLastPathComponent().path(percentEncoded: false)
            guard let root = await root(of: directory, known: &knownRoots) else { continue }

            byRoot[root, default: []].append(file)
            roots[root] = max(roots[root] ?? .distantPast, file.touchedAt)
        }

        guard !Task.isCancelled else { return }

        repositories = await collect(roots: roots, touched: byRoot)
        checkedAt = Date()
    }

    func root(of directory: String, known: inout [String: String?]) async -> String? {
        if let cached = known[directory] { return cached }

        if let inherited = GitRootResolver.inherited(for: directory, from: Set(known.values.compactMap(\.self))) {
            known[directory] = inherited
            return inherited
        }

        let root = await GitClient.root(for: URL(filePath: directory))
        known[directory] = root
        return root
    }

    func collect(
        roots: [String: Date],
        touched: [String: [AgentTouchedFile]]
    ) async -> [AgentRepositoryChanges] {
        var found: [AgentRepositoryChanges] = []

        for (root, touchedAt) in roots {
            guard !Task.isCancelled else { break }

            let changes = await GitClient.changes(at: URL(filePath: root))
            let changed = Set(changes.map { Self.resolved(URL(filePath: root + "/" + $0.path)) })
            let untouched = (touched[root] ?? [])
                .filter { !changed.contains(Self.resolved($0.url)) }
                .sorted { $0.touchedAt > $1.touchedAt }
                .prefix(Limit.touchedPerRepository)

            guard !changes.isEmpty || !untouched.isEmpty else { continue }

            found.append(AgentRepositoryChanges(
                root: root,
                changes: changes,
                touchedOnly: Array(untouched),
                touchedAt: touchedAt
            ))
        }

        return found.sorted { ($0.touchedAt, $1.root) > ($1.touchedAt, $0.root) }
    }

    static func resolved(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path(percentEncoded: false)
    }
}
