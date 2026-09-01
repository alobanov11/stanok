import Foundation

public struct AgentSessionDay: Identifiable, Sendable {

    public var id: Date {
        start
    }

    public let start: Date
    public let title: String
    public let sessions: [AgentSession]

    public init(start: Date, title: String, sessions: [AgentSession]) {
        self.start = start
        self.title = title
        self.sessions = sessions
    }
}
