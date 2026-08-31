import Foundation

public enum AgentSessionFilter {

    public static func matches(_ session: AgentSession, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }

        if session.title.lowercased().contains(needle) { return true }

        if
            let folder = session.folder?.path(percentEncoded: false).lowercased(),
            folder.contains(needle) {
            return true
        }

        return false
    }

    public static func apply(_ query: String, to sessions: [AgentSession]) -> [AgentSession] {
        sessions.filter { matches($0, query: query) }
    }
}
