import Foundation

public struct AgentTouchedFile: Sendable, Equatable {

    public let url: URL
    public let touchedAt: Date

    public init(url: URL, touchedAt: Date) {
        self.url = url
        self.touchedAt = touchedAt
    }
}
