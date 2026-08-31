import Foundation

public struct Repository: Identifiable, Codable, Equatable {

    private enum CodingKeys: String, CodingKey {

        case id
        case url
        case sessions
        case isExpanded
        case lastOpenedAt
        case openCount
        case workspace
    }

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

    public var workspace: WorkspaceState

    public init(
        url: URL,
        id: UUID = UUID(),
        sessions: [TerminalSession] = [],
        isExpanded: Bool = true,
        lastOpenedAt: Date = .distantPast,
        openCount: Int = 0,
        workspace: WorkspaceState = WorkspaceState()
    ) {
        self.id = id
        self.url = url
        self.sessions = sessions
        self.isExpanded = isExpanded
        self.lastOpenedAt = lastOpenedAt
        self.openCount = openCount
        self.workspace = workspace
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.url = try container.decode(URL.self, forKey: .url)
        self.sessions = try container.decode([TerminalSession].self, forKey: .sessions)
        self.isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        self.lastOpenedAt = try container.decode(Date.self, forKey: .lastOpenedAt)
        self.openCount = try container.decode(Int.self, forKey: .openCount)
        self.workspace = try container.decodeIfPresent(WorkspaceState.self, forKey: .workspace)
            ?? WorkspaceState()
    }
}
