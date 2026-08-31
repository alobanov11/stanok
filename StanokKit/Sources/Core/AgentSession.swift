import Foundation

public struct AgentSession: Identifiable, Equatable, Sendable {

    public let id: AgentSessionKey

    public let title: String

    public let lastActivityAt: Date

    public let resumeAction: AgentResumeAction

    public let folder: URL?

    public init(
        id: AgentSessionKey,
        title: String,
        lastActivityAt: Date,
        resumeAction: AgentResumeAction,
        folder: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.lastActivityAt = lastActivityAt
        self.resumeAction = resumeAction
        self.folder = folder
    }
}
