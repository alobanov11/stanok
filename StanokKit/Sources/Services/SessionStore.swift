import Foundation

@MainActor
@Observable
public final class SessionStore {

    public var roots: [TerminalSession] {
        sessions.filter { $0.parentID == nil }
    }

    public private(set) var sessions: [TerminalSession] = []

    public private(set) var selectedSessionID: TerminalSession.ID?

    private let file: URL
    private let legacyFile: URL

    @ObservationIgnored
    private lazy var saveScheduler = SaveScheduler<SessionFile>(
        delay: .milliseconds(400)
    ) { [weak self] snapshot in
        self?.persistVerified(snapshot)
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

    public func removeSession(_ sessionID: TerminalSession.ID) {
        guard let session = session(for: sessionID) else { return }

        if session.parentID == nil {
            removeRoot(session)
        } else {
            removePane(session)
        }

        save()
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

    func removeRoot(_ root: TerminalSession) {
        let remaining = root.layout?.removing(root.id)
        sessions.removeAll { $0.id == root.id }

        guard
            let remaining,
            let heirID = remaining.leafIDs.first,
            let heirIndex = sessions.firstIndex(where: { $0.id == heirID })
        else {
            sessions.removeAll { $0.parentID == root.id }
            return
        }

        sessions[heirIndex].parentID = nil
        sessions[heirIndex].layout = pruned(remaining, soleLeaf: heirID)

        for index in sessions.indices where sessions[index].parentID == root.id {
            sessions[index].parentID = heirID
        }
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

    func persistVerified(_ snapshot: SessionFile) {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)

            let temporary = file.deletingLastPathComponent()
                .appending(path: "\(file.lastPathComponent).tmp-\(UUID().uuidString)")
            try data.write(to: temporary, options: .atomic)

            let roundTripped = try JSONDecoder().decode(
                SessionFile.self,
                from: Data(contentsOf: temporary)
            )
            guard roundTripped == snapshot else {
                fatalError("stanok: sessions.json failed round-trip verification, refusing to save")
            }

            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                _ = try FileManager.default.replaceItemAt(file, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: file)
            }
        } catch {
            Log.terminal.error("cannot save sessions: \(error.localizedDescription)")
        }
    }
}
