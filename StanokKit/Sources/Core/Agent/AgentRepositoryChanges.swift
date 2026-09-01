import Foundation

public struct AgentRepositoryChanges: Identifiable, Sendable {

    public var id: String {
        root
    }

    public var name: String {
        URL(filePath: root).lastPathComponent
    }

    public let root: String
    public let changes: [GitChange]
    public let touchedOnly: [AgentTouchedFile]
    public let touchedAt: Date

    public init(
        root: String,
        changes: [GitChange],
        touchedOnly: [AgentTouchedFile],
        touchedAt: Date
    ) {
        self.root = root
        self.changes = changes
        self.touchedOnly = touchedOnly
        self.touchedAt = touchedAt
    }
}
