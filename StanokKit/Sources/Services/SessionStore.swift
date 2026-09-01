import Foundation

@MainActor
@Observable
public final class SessionStore {

    public static let shared = SessionStore()

    public var roots: [TerminalSession] {
        sessions.filter { $0.parentID == nil }
    }

    public private(set) var sessions: [TerminalSession] = []

    public private(set) var unreachable: Set<TerminalSession.ID> = []

    public private(set) var selectedSessionID: TerminalSession.ID?

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
    public func addSession(url: URL) -> TerminalSession {
        let session = TerminalSession(name: "shell \(sessions.count + 1)", url: url)
        sessions.append(session)
        save()
        return session
    }

    @discardableResult
    public func splitSession(
        _ sessionID: TerminalSession.ID,
        direction: SplitDirection
    ) -> TerminalSession? {
        guard
            let source = session(for: sessionID),
            let root = root(of: sessionID),
            let rootIndex = sessions.firstIndex(where: { $0.id == root.id })
        else { return nil }

        let layout = root.layout ?? .leaf(root.id)
        guard layout.contains(sessionID) else { return nil }

        let pane = TerminalSession(
            name: "shell \(sessions.count + 1)",
            url: source.url,
            parentID: root.id
        )

        sessions[rootIndex].layout = layout.inserting(pane.id, direction, near: sessionID)
        sessions.append(pane)
        save()
        return pane
    }

    public func moveRoot(_ sessionID: TerminalSession.ID, to index: Int) {
        var order = roots.map(\.id)
        guard let from = order.firstIndex(of: sessionID) else { return }

        let destination = min(max(index, 0), order.count - 1)
        guard from != destination else { return }

        order.remove(at: from)
        order.insert(sessionID, at: destination)
        regroup(order)
        save()
    }

    @discardableResult
    public func removeSession(_ sessionID: TerminalSession.ID) -> TerminalSession.ID? {
        guard let session = session(for: sessionID) else { return nil }

        let heir = session.parentID == nil ? removeRoot(session) : nil
        if session.parentID != nil { removePane(session) }

        save()
        return heir
    }

    public func root(of sessionID: TerminalSession.ID) -> TerminalSession? {
        guard let session = session(for: sessionID) else { return nil }
        guard let parentID = session.parentID else { return session }

        return self.session(for: parentID)
    }

    public func panes(of root: TerminalSession) -> [TerminalSession] {
        guard let layout = root.layout else { return [root] }

        return layout.leafIDs.compactMap { id in sessions.first { $0.id == id } }
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

    func removePane(_ pane: TerminalSession) {
        sessions.removeAll { $0.id == pane.id }

        guard
            let parentID = pane.parentID,
            let parentIndex = sessions.firstIndex(where: { $0.id == parentID })
        else { return }

        sessions[parentIndex].layout = pruned(
            sessions[parentIndex].layout?.removing(pane.id),
            soleLeaf: parentID
        )
    }

    @discardableResult
    func removeRoot(_ root: TerminalSession) -> TerminalSession.ID? {
        let remaining = root.layout?.removing(root.id)
        let position = sessions.firstIndex { $0.id == root.id }
        sessions.removeAll { $0.id == root.id }

        guard
            let remaining,
            let heirID = remaining.leafIDs.first,
            let heirIndex = sessions.firstIndex(where: { $0.id == heirID })
        else {
            sessions.removeAll { $0.parentID == root.id }
            return nil
        }

        sessions[heirIndex].parentID = nil
        sessions[heirIndex].header = root.header
        sessions[heirIndex].layout = pruned(remaining, soleLeaf: heirID)

        for index in sessions.indices where sessions[index].parentID == root.id {
            sessions[index].parentID = heirID
        }

        if let position {
            let heir = sessions.remove(at: heirIndex)
            sessions.insert(heir, at: min(position, sessions.count))
        }

        regroup(sessions.filter { $0.parentID == nil }.map(\.id))

        return heirID
    }

    func pruned(_ layout: SplitLayout?, soleLeaf: UUID) -> SplitLayout? {
        guard let layout, layout != .leaf(soleLeaf) else { return nil }

        return layout
    }

    func normalizeGroups() {
        var changed = false

        for index in sessions.indices {
            guard let parentID = sessions[index].parentID else { continue }

            guard
                let parentIndex = sessions.firstIndex(where: { $0.id == parentID }),
                sessions[parentIndex].parentID == nil
            else {
                sessions[index].parentID = nil
                changed = true
                continue
            }

            let layout = sessions[parentIndex].layout ?? .leaf(parentID)
            guard !layout.contains(sessions[index].id) else { continue }

            sessions[parentIndex].layout = layout.inserting(
                sessions[index].id,
                .trailing,
                near: layout.leafIDs.last ?? parentID
            )
            changed = true
        }

        let known = Set(sessions.map(\.id))

        for index in sessions.indices {
            guard let layout = sessions[index].layout else { continue }

            let strays = layout.leafIDs.filter { !known.contains($0) }
            guard !strays.isEmpty else { continue }

            var kept = layout
            for stray in strays {
                kept = kept.removing(stray) ?? .leaf(sessions[index].id)
            }

            sessions[index].layout = pruned(kept, soleLeaf: sessions[index].id)
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
        SessionFile(sessions: sessions, selectedSessionID: selectedSessionID)
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
