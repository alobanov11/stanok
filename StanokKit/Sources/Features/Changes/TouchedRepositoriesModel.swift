import Foundation

@MainActor
@Observable
public final class TouchedRepositoriesModel {

    private enum Limit {

        static let touchedPerRepository = 60
    }

    public private(set) var repositories: [TouchedRepository] = []

    public private(set) var isLoading = false

    public private(set) var checkedAt: Date?

    @ObservationIgnored
    private var source: (any AgentTouchesSource)?

    @ObservationIgnored
    private var running: Task<Void, Never>?

    @ObservationIgnored
    private var focused: String?

    @ObservationIgnored
    private var runningToken = UUID()

    public nonisolated init() {}

    public func use(_ source: any AgentTouchesSource) {
        self.source = source
    }

    public func focus(on root: String?) {
        guard focused != root else { return }

        // Почему: область поиска сменилась, идущий проход собирает уже не тот репозиторий
        focused = root
        repositories = []
        stop()
    }

    public func stop() {
        running?.cancel()
        running = nil
        runningToken = UUID()
        isLoading = false
    }

    public func refresh() async {
        // Почему: проход живёт отдельно от вызывающего, иначе закрытая панель обрывает его на полпути
        if let running {
            await running.value
            return
        }

        let token = UUID()
        runningToken = token
        isLoading = true

        let task = Task { _ = try? await reload() }
        running = task
        await task.value

        guard runningToken == token else { return }

        running = nil
        isLoading = false
    }
}

private extension TouchedRepositoriesModel {

    func reload() async throws {
        guard let source else { return }

        let scope = focused
        let touched = await source.touched(scope: scope)
        try Task.checkCancellation()

        let collected = try await Self.build(touched: touched, focused: scope)
        try Task.checkCancellation()

        repositories = collected
        checkedAt = Date()
    }

    // Почему: разбор путей и сборка деревьев не должны занимать главный поток
    nonisolated static func build(
        touched: (files: [AgentTouchedFile], directories: Set<String>),
        focused: String?
    ) async throws -> [TouchedRepository] {
        var roots: [String: Date] = [:]
        var byRoot: [String: [AgentTouchedFile]] = [:]
        var knownRoots: [String: String?] = [:]
        var discovered: Set<String> = []

        for directory in touched.directories.sorted() {
            try Task.checkCancellation()
            // Почему: внутри .build и node_modules лежат чужие репозитории зависимостей
            guard !IgnoredPaths.contains(relativePath: directory) else { continue }
            guard let root = await Self.root(of: directory, known: &knownRoots, found: &discovered)
            else { continue }

            roots[root] = roots[root] ?? .distantPast
        }

        for file in touched.files {
            try Task.checkCancellation()

            let directory = file.url.deletingLastPathComponent().path(percentEncoded: false)
            guard !IgnoredPaths.contains(relativePath: directory) else { continue }
            guard let root = await Self.root(of: directory, known: &knownRoots, found: &discovered)
            else { continue }

            byRoot[root, default: []].append(file)
            roots[root] = max(roots[root] ?? .distantPast, file.touchedAt)
        }

        try Task.checkCancellation()

        return try await collect(roots: roots, touched: byRoot, focused: focused)
    }

    nonisolated static func root(
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

    nonisolated static func collect(
        roots: [String: Date],
        touched: [String: [AgentTouchedFile]],
        focused: String?
    ) async throws -> [TouchedRepository] {
        var found: [TouchedRepository] = []

        for (root, touchedAt) in roots {
            try Task.checkCancellation()

            let changes = await GitClient.changes(at: URL(filePath: root))
            let changed = Set(changes.map { Self.resolved(URL(filePath: root + "/" + $0.path)) })
            let untouched = (touched[root] ?? [])
                .filter { !changed.contains(Self.resolved($0.url)) }
                .sorted { $0.touchedAt > $1.touchedAt }
                .prefix(Limit.touchedPerRepository)

            guard !changes.isEmpty || !untouched.isEmpty else { continue }

            found.append(TouchedRepository(
                root: root,
                changes: changes,
                touchedOnly: Array(untouched),
                touchedAt: touchedAt
            ))
        }

        return ordered(found, focused: focused)
    }

    // Почему: репозиторий открытого терминала читают первым, остальные идут ровным списком
    nonisolated static func ordered(
        _ items: [TouchedRepository],
        focused: String?
    ) -> [TouchedRepository] {
        items.sorted {
            let left = $0.root == focused ? 0 : 1
            let right = $1.root == focused ? 0 : 1

            return left == right ? $0.root < $1.root : left < right
        }
    }

    nonisolated static func resolved(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path(percentEncoded: false)
    }
}
