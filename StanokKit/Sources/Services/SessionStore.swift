import Foundation

@MainActor
@Observable
public final class SessionStore {

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

    public func removeSession(_ sessionID: TerminalSession.ID) {
        sessions.removeAll { $0.id == sessionID }
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

    public func flushPendingSave() {
        saveScheduler.flush()
    }

    public func session(for sessionID: TerminalSession.ID?) -> TerminalSession? {
        guard let sessionID else { return nil }

        return sessions.first { $0.id == sessionID }
    }

    private func load() {
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            loadSessionsFile()
        } else {
            migrateFromLegacyFile()
        }
    }

    private func loadSessionsFile() {
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

    private func migrateFromLegacyFile() {
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

    private func loadLegacyRepositories() -> [LegacyRepository] {
        guard let data = try? Data(contentsOf: legacyFile) else { return [] }

        do {
            return try JSONDecoder().decode([LegacyRepository].self, from: data)
        } catch {
            fatalError("stanok: repositories.json exists but failed to decode — \(error)")
        }
    }

    private func flattenLegacyRepositoriesOrCrash(
        _ legacyRepositories: [LegacyRepository]
    ) -> [TerminalSession] {
        do {
            return try SessionMigration.flatten(legacyRepositories)
        } catch {
            fatalError("stanok: migration invariant violated, refusing to write — \(error)")
        }
    }

    private func seedInitialSession() {
        let session = TerminalSession(
            name: "shell",
            url: FileManager.default.homeDirectoryForCurrentUser
        )
        sessions = [session]
        selectedSessionID = session.id
        persistVerified(currentSnapshot())
    }

    private func save() {
        saveScheduler.schedule(currentSnapshot())
        saveScheduler.flush()
    }

    private func currentSnapshot() -> SessionFile {
        SessionFile(sessions: sessions, selectedSessionID: selectedSessionID)
    }

    private func persistVerified(_ snapshot: SessionFile) {
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
