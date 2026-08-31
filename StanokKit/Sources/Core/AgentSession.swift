import Foundation

public struct AgentSession: Identifiable, Equatable, Sendable {

    public let id: AgentSessionKey

    public let title: String

    public let lastActivityAt: Date

    public let resumeAction: AgentResumeAction

    public init(
        id: AgentSessionKey,
        title: String,
        lastActivityAt: Date,
        resumeAction: AgentResumeAction
    ) {
        self.id = id
        self.title = title
        self.lastActivityAt = lastActivityAt
        self.resumeAction = resumeAction
    }
}
