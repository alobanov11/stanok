import Foundation

enum WorkingDirectoryTracker {

    @MainActor
    static func report(_ raw: String, for sessionID: TerminalSession.ID, into store: SessionStore) {
        guard let urls = WorkingDirectoryReport.urls(fromPwd: raw) else { return }

        store.updateDirectory(sessionID, identity: urls.identity, reported: urls.reported)
    }
}
