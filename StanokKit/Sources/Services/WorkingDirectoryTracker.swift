import Foundation

@MainActor
final class WorkingDirectoryTracker {

    private var generations = CwdGenerationTracker()

    func report(_ raw: String, for sessionID: TerminalSession.ID, into store: SessionStore) {
        guard let urls = WorkingDirectoryReport.urls(fromPwd: raw) else { return }

        let generation = generations.advance(for: sessionID)
        guard generations.isCurrent(generation, for: sessionID) else { return }

        store.updateDirectory(sessionID, identity: urls.identity, reported: urls.reported)
    }
}
