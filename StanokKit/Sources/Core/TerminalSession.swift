import Foundation

public struct TerminalSession: Identifiable, Codable, Equatable {

    private enum CodingKeys: String, CodingKey {

        case id
        case name
        case url
        case workspace
    }

    public var displayName: String { liveTitle ?? name }

    public var isReachable: Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    public let id: UUID

    public var name: String

    public var url: URL

    public var workspace: WorkspaceState

    public var liveTitle: String?

    public var liveDirectory: URL?

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        workspace: WorkspaceState = WorkspaceState(),
        liveTitle: String? = nil,
        liveDirectory: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.workspace = workspace
        self.liveTitle = liveTitle
        self.liveDirectory = liveDirectory
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.workspace = try container.decode(WorkspaceState.self, forKey: .workspace)
        self.liveTitle = nil
        self.liveDirectory = nil
    }

    public static func == (lhs: TerminalSession, rhs: TerminalSession) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.url == rhs.url
            && lhs.workspace == rhs.workspace
    }
}
