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

    @ObservationIgnored
    private var running: Task<Void, Never>?

    public nonisolated init() {}

    public func use(_ source: any AgentTouchesSource) {
        self.source = source
    }

    public func refresh() async {
        // Почему: проход живёт отдельно от вызывающего, иначе закрытая панель обрывает его на полпути
        if let running {
            await running.value
            return
        }

        isLoading = true

        let task = Task { _ = try? await reload() }
        running = task
        await task.value
        running = nil
        isLoading = false
    }
}

private extension AgentChangesModel {

    func reload() async throws {
        guard let source else { return }

        let touched = await source.touched()
        try Task.checkCancellation()

        var roots: [String: Date] = [:]
        var byRoot: [String: [AgentTouchedFile]] = [:]
        var knownRoots: [String: String?] = [:]
        var discovered: Set<String> = []

        for directory in touched.directories.sorted() {
            try Task.checkCancellation()
            guard let root = await root(of: directory, known: &knownRoots, found: &discovered) else { continue }

            roots[root] = roots[root] ?? .distantPast
        }

        for file in touched.files {
            try Task.checkCancellation()

            let directory = file.url.deletingLastPathComponent().path(percentEncoded: false)
            guard let root = await root(of: directory, known: &knownRoots, found: &discovered) else { continue }

            byRoot[root, default: []].append(file)
            roots[root] = max(roots[root] ?? .distantPast, file.touchedAt)
        }

        try Task.checkCancellation()

        let collected = try await collect(roots: roots, touched: byRoot)
        try Task.checkCancellation()

        repositories = collected
        checkedAt = Date()
    }

    func root(
        of directory: String,
        known: inout [String: String?],
        found: inout Set<String>
    ) async -> String? {
        if let cached = known[directory] { return cached }

        if let inherited = GitRootResolver.inherited(for: directory, from: found) {
            known[directory] = inherited
            return inherited
        }

        let root = await GitClient.root(for: URL(filePath: directory))
        known[directory] = root
        if let root { found.insert(root) }

        return root
    }

    func collect(
        roots: [String: Date],
        touched: [String: [AgentTouchedFile]]
    ) async throws -> [AgentRepositoryChanges] {
        var found: [AgentRepositoryChanges] = []

        for (root, touchedAt) in roots {
            try Task.checkCancellation()

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

        return found.sorted {
            $0.touchedAt == $1.touchedAt ? $0.root < $1.root : $0.touchedAt > $1.touchedAt
        }
    }

    static func resolved(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path(percentEncoded: false)
    }
}
