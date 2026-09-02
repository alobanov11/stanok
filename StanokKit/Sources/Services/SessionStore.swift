import Foundation

@MainActor
@Observable
public final class SessionStore {

    public static let shared = SessionStore()

    public var roots: [TerminalSession] {
        sessions
    }

    public private(set) var sessions: [TerminalSession] = []

    public private(set) var unreachable: Set<TerminalSession.ID> = []

    public private(set) var selectedSessionID: TerminalSession.ID?

    // Почему: рабочая область — один ряд, порядок в нём задаётся порядком самих терминалов
    public private(set) var shown: [TerminalSession.ID] = []

    private let file: URL
    private let legacyFile: URL

    @ObservationIgnored
    private lazy var saveScheduler = SaveScheduler<SessionFile>(
        delay: .milliseconds(400)
    ) { [weak self] snapshot in
        self?.persistVerified(snapshot) ?? false
    }

    public init(file: URL = AppPaths.sessions, legacyFile: URL = AppPaths.repositories) {
        self.file = file
        self.legacyFile = legacyFile
        load()
    }

    @discardableResult
    public func addSession(url: URL, agent: String? = nil) -> TerminalSession {
        let session = TerminalSession(
            name: "shell \(sessions.count + 1)",
            agent: agent,
            url: url
        )
        sessions.append(session)
        save()
        return session
    }

    public func moveRoot(_ sessionID: TerminalSession.ID, to index: Int) {
        guard let from = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        let destination = min(max(index, 0), sessions.count - 1)
        guard from != destination else { return }

        let session = sessions.remove(at: from)
        sessions.insert(session, at: destination)
        save()
    }

    @discardableResult
    public func removeSession(_ sessionID: TerminalSession.ID) -> TerminalSession.ID? {
        guard sessions.contains(where: { $0.id == sessionID }) else { return nil }

        sessions.removeAll { $0.id == sessionID }
        shown.removeAll { $0 == sessionID }
        save()

        return nil
    }

    public func root(of sessionID: TerminalSession.ID) -> TerminalSession? {
        session(for: sessionID)
    }

    public func setTitle(_ title: String?, for sessionID: TerminalSession.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].title != title else { return }

        sessions[index].title = title
        save()
    }

    public func setHeader(_ header: String?, for sessionID: TerminalSession.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].header != header else { return }

        sessions[index].header = header
        save()
    }

    public func setLiveTitle(_ title: String?, for sessionID: TerminalSession.ID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        sessions[index].liveTitle = title
    }

    public func show(_ sessionID: TerminalSession.ID, capacity: Int, replacing: TerminalSession.ID?) {
        guard !shown.contains(sessionID) else { return }

        if shown.count >= max(capacity, 1), let replacing, shown.contains(replacing) {
            shown.removeAll { $0 == replacing }
        }

        while shown.count >= max(capacity, 1), !shown.isEmpty {
            shown.removeFirst()
        }

        shown.append(sessionID)
        saveScheduler.schedule(currentSnapshot())
    }

    // Почему: при сужении окна лишние терминалы уходят в сайдбар, а не сжимаются в полоску
    public func limit(to capacity: Int, keeping selected: TerminalSession.ID?) {
        let room = max(capacity, 1)
        guard shown.count > room else { return }

        var kept = shown
        while kept.count > room {
            guard let victim = kept.first(where: { $0 != selected }) else { break }

            kept.removeAll { $0 == victim }
        }

        shown = kept
        saveScheduler.schedule(currentSnapshot())
    }

    public func hide(_ sessionID: TerminalSession.ID) {
        guard shown.contains(sessionID) else { return }

        shown.removeAll { $0 == sessionID }
        saveScheduler.schedule(currentSnapshot())
    }

    // Почему: перетаскивание меняет порядок терминалов, а место в ряду выводится из него
    public func move(_ moved: TerminalSession.ID, before target: TerminalSession.ID) {
        guard
            moved != target,
            let from = sessions.firstIndex(where: { $0.id == moved }),
            let to = sessions.firstIndex(where: { $0.id == target })
        else { return }

        let session = sessions.remove(at: from)
        sessions.insert(session, at: sessions.index(from < to ? to - 1 : to, offsetBy: 0))
        save()
    }

    public func select(_ sessionID: TerminalSession.ID?) {
        guard selectedSessionID != sessionID else { return }

        selectedSessionID = sessionID
        saveScheduler.schedule(currentSnapshot())
    }

    public func updateWorkspace(
        _ sessionID: TerminalSession.ID,
        mutate: (inout WorkspaceState) -> Void
    ) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }

        mutate(&sessions[index].workspace)
        saveScheduler.schedule(currentSnapshot())
    }

    public func updateDirectory(_ sessionID: TerminalSession.ID, identity: URL, reported: URL) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].url != identity || sessions[index].liveDirectory != reported else {
            return
        }

        sessions[index].url = identity
        sessions[index].liveDirectory = reported
        saveScheduler.schedule(currentSnapshot())
    }

    public func refreshReachability() async {
        let paths = sessions.map { ($0.id, $0.url.path(percentEncoded: false)) }
        let missing = await Task.detached(priority: .utility) {
            Set(paths.filter { !FileManager.default.fileExists(atPath: $0.1) }.map(\.0))
        }.value

        guard missing != unreachable else { return }

        unreachable = missing
    }

    public func flushPendingSave() {
        saveScheduler.flush()
    }

    public func session(for sessionID: TerminalSession.ID?) -> TerminalSession? {
        guard let sessionID else { return nil }

        return sessions.first { $0.id == sessionID }
    }
}

private extension SessionStore {

    func regroup(_ order: [TerminalSession.ID]) {
        var grouped: [TerminalSession] = []

        for rootID in order {
            guard let root = sessions.first(where: { $0.id == rootID }) else { continue }

            grouped.append(root)
            grouped.append(contentsOf: sessions.filter { $0.parentID == rootID })
        }

        let placed = Set(grouped.map(\.id))
        grouped.append(contentsOf: sessions.filter { !placed.contains($0.id) })
        sessions = grouped
    }

    // Почему: вложенных терминалов больше нет, миграция просто выпрямляет старые записи
    func normalizeGroups() {
        var changed = false

        for index in sessions.indices where sessions[index].parentID != nil {
            sessions[index].parentID = nil
            changed = true
        }

        for index in sessions.indices where sessions[index].layout != nil {
            sessions[index].layout = nil
            changed = true
        }

        guard changed else { return }

        persistVerified(currentSnapshot())
    }

    func load() {
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            loadSessionsFile()
        } else {
            migrateFromLegacyFile()
        }

        normalizeGroups()
    }

    func loadSessionsFile() {
        guard let data = try? Data(contentsOf: file) else {
            fatalError("stanok: sessions.json exists but could not be read at \(file.path())")
        }

        do {
            let decoded = try JSONDecoder().decode(SessionFile.self, from: data)
            sessions = decoded.sessions
            selectedSessionID = decoded.selectedSessionID
            shown = decoded.shown.filter { id in decoded.sessions.contains { $0.id == id } }
        } catch {
            fatalError("stanok: sessions.json is corrupt, refusing to fall back — \(error)")
        }
    }

    func migrateFromLegacyFile() {
        let legacyRepositories = loadLegacyRepositories()
        let migratedSessions = flattenLegacyRepositoriesOrCrash(legacyRepositories)

        guard !migratedSessions.isEmpty else {
            seedInitialSession()
            return
        }

        let selection = SessionMigration.resolveSelectedSessionID(
            legacyRepositories: legacyRepositories,
            sessions: migratedSessions
        )

        sessions = migratedSessions
        selectedSessionID = selection
        persistVerified(currentSnapshot())
    }

    func loadLegacyRepositories() -> [LegacyRepository] {
        guard let data = try? Data(contentsOf: legacyFile) else { return [] }

        do {
            return try JSONDecoder().decode([LegacyRepository].self, from: data)
        } catch {
            fatalError("stanok: repositories.json exists but failed to decode — \(error)")
        }
    }

    func flattenLegacyRepositoriesOrCrash(
        _ legacyRepositories: [LegacyRepository]
    ) -> [TerminalSession] {
        do {
            return try SessionMigration.flatten(legacyRepositories)
        } catch {
            fatalError("stanok: migration invariant violated, refusing to write — \(error)")
        }
    }

    func seedInitialSession() {
        let session = TerminalSession(
            name: "shell",
            url: FileManager.default.homeDirectoryForCurrentUser
        )
        sessions = [session]
        selectedSessionID = session.id
        persistVerified(currentSnapshot())
    }

    func save() {
        saveScheduler.schedule(currentSnapshot())
        saveScheduler.flush()
    }

    func currentSnapshot() -> SessionFile {
        SessionFile(sessions: sessions, selectedSessionID: selectedSessionID, shown: shown)
    }

    @discardableResult
    func persistVerified(_ snapshot: SessionFile) -> Bool {
        var temporary: URL?

        defer {
            if
                let temporary, FileManager.default.fileExists(
                    atPath: temporary.path(percentEncoded: false)
                ) {
                try? FileManager.default.removeItem(at: temporary)
            }
        }

        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)

            let target = file.deletingLastPathComponent()
                .appending(path: "\(file.lastPathComponent).tmp-\(UUID().uuidString)")
            temporary = target
            try data.write(to: target, options: .atomic)

            let roundTripped = try JSONDecoder().decode(
                SessionFile.self,
                from: Data(contentsOf: target)
            )
            guard roundTripped == snapshot else {
                fatalError("stanok: sessions.json failed round-trip verification, refusing to save")
            }

            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                _ = try FileManager.default.replaceItemAt(file, withItemAt: target)
            } else {
                try FileManager.default.moveItem(at: target, to: file)
            }

            return true
        } catch {
            Log.terminal.error("cannot save sessions: \(error.localizedDescription)")
            return false
        }
    }
}
