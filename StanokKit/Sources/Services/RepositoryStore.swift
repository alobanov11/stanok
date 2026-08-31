import Foundation

@MainActor
@Observable
public final class RepositoryStore {

    public var pinned: [PinnedSession] {
        repositories.flatMap { repository in
            repository.sessions
                .filter(\.isPinned)
                .map { PinnedSession(repository: repository, session: $0) }
        }
    }

    public private(set) var repositories: [Repository] = []

    private let file: URL

    @ObservationIgnored
    private lazy var saveScheduler = SaveScheduler<[Repository]>(
        delay: .milliseconds(400)
    ) { [weak self] snapshot in
        self?.persist(snapshot)
    }

    public init(file: URL = AppPaths.repositories) {
        self.file = file
        load()

        if repositories.isEmpty {
            add(FileManager.default.homeDirectoryForCurrentUser)
        }
    }

    @discardableResult
    public func add(_ url: URL) -> TerminalSession? {
        if let index = repositories.firstIndex(where: { $0.url == url }) {
            touch(repositories[index].id)
            return repositories[index].sessions.first
        }

        let session = TerminalSession(name: "shell")
        repositories.insert(
            Repository(url: url, sessions: [session], lastOpenedAt: .now, openCount: 1),
            at: 0
        )
        save()
        return session
    }

    public func remove(_ repository: Repository) {
        repositories.removeAll { $0.id == repository.id }
        save()
    }

    @discardableResult
    public func addSession(to repositoryID: Repository.ID) -> TerminalSession? {
        guard let index = repositories.firstIndex(where: { $0.id == repositoryID })
        else { return nil }

        let session = TerminalSession(name: "shell \(repositories[index].sessions.count + 1)")
        repositories[index].sessions.append(session)
        repositories[index].isExpanded = true
        save()
        return session
    }

    public func removeSession(_ sessionID: TerminalSession.ID) {
        for index in repositories.indices {
            repositories[index].sessions.removeAll { $0.id == sessionID }
        }
        save()
    }

    public func setLiveTitle(_ title: String?, for sessionID: TerminalSession.ID) {
        for repositoryIndex in repositories.indices {
            guard
                let index = repositories[repositoryIndex].sessions
                    .firstIndex(where: { $0.id == sessionID })
            else { continue }

            repositories[repositoryIndex].sessions[index].liveTitle = title
            return
        }
    }

    public func toggleExpansion(_ repositoryID: Repository.ID) {
        guard let index = repositories.firstIndex(where: { $0.id == repositoryID }) else { return }

        repositories[index].isExpanded.toggle()
        save()
    }

    public func touch(_ repositoryID: Repository.ID) {
        guard let index = repositories.firstIndex(where: { $0.id == repositoryID }) else { return }

        repositories[index].lastOpenedAt = .now
        repositories[index].openCount += 1
        save()
    }

    public func togglePin(_ sessionID: TerminalSession.ID) {
        for repositoryIndex in repositories.indices {
            guard
                let index = repositories[repositoryIndex].sessions
                    .firstIndex(where: { $0.id == sessionID })
            else { continue }

            repositories[repositoryIndex].sessions[index].isPinned.toggle()
            save()
            return
        }
    }

    public func updateWorkspace(
        _ repositoryID: Repository.ID,
        mutate: (inout WorkspaceState) -> Void
    ) {
        guard let index = repositories.firstIndex(where: { $0.id == repositoryID }) else { return }

        mutate(&repositories[index].workspace)
        saveScheduler.schedule(repositories)
    }

    public func flushPendingSave() {
        saveScheduler.flush()
    }

    public func repository(hosting sessionID: TerminalSession.ID) -> Repository? {
        repositories.first { $0.sessions.contains { $0.id == sessionID } }
    }

    private func load() {
        guard let data = try? Data(contentsOf: file) else { return }

        do {
            repositories = try JSONDecoder().decode([Repository].self, from: data)
            sort()
        } catch {
            Log.terminal.error("cannot decode repositories: \(error.localizedDescription)")
            quarantine()
        }
    }

    private func quarantine() {
        try? FileManager.default.moveItem(at: file, to: uniqueBackupURL())
    }

    private func uniqueBackupURL() -> URL {
        let timestamp = Int(Date.now.timeIntervalSince1970)
        var candidate = file.appendingPathExtension("corrupt-\(timestamp)")
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = file.appendingPathExtension("corrupt-\(timestamp)-\(index)")
            index += 1
        }

        return candidate
    }

    private func sort() {
        repositories.sort { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    private func save() {
        saveScheduler.schedule(repositories)
        saveScheduler.flush()
    }

    private func persist(_ repositories: [Repository]) {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(repositories).write(to: file, options: .atomic)
        } catch {
            Log.terminal.error("cannot save repositories: \(error.localizedDescription)")
        }
    }
}
