import Foundation

public struct Repository: Identifiable, Codable, Equatable {

    public var name: String { url.lastPathComponent }

    public var isReachable: Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    public let id: UUID

    public let url: URL

    public var sessions: [TerminalSession]

    public var isExpanded: Bool

    public var lastOpenedAt: Date

    public var openCount: Int

    public init(
        url: URL,
        id: UUID = UUID(),
        sessions: [TerminalSession] = [],
        isExpanded: Bool = true,
        lastOpenedAt: Date = .distantPast,
        openCount: Int = 0
    ) {
        self.id = id
        self.url = url
        self.sessions = sessions
        self.isExpanded = isExpanded
        self.lastOpenedAt = lastOpenedAt
        self.openCount = openCount
    }
}
