import Foundation

public struct TerminalSession: Identifiable, Codable, Equatable {

    private enum CodingKeys: String, CodingKey {

        case id
        case name
        case title
        case header
        case agent
        case url
        case workspace
        case parentID
        case layout
    }

    public var displayName: String {
        title ?? liveTitle ?? name
    }

    public var name: String
    public var title: String?
    public var header: String?
    public var agent: String?
    public var url: URL
    public var workspace: WorkspaceState
    public var parentID: UUID?
    public var layout: SplitLayout?
    public var liveTitle: String?
    public var liveDirectory: URL?

    public let id: UUID

    public init(
        id: UUID = UUID(),
        name: String,
        title: String? = nil,
        header: String? = nil,
        agent: String? = nil,
        url: URL,
        workspace: WorkspaceState = WorkspaceState(),
        parentID: UUID? = nil,
        layout: SplitLayout? = nil,
        liveTitle: String? = nil,
        liveDirectory: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.header = header
        self.agent = agent
        self.url = url
        self.workspace = workspace
        self.parentID = parentID
        self.layout = layout
        self.liveTitle = liveTitle
        self.liveDirectory = liveDirectory
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.header = try container.decodeIfPresent(String.self, forKey: .header)
        self.agent = try container.decodeIfPresent(String.self, forKey: .agent)
        self.url = try container.decode(URL.self, forKey: .url)
        self.workspace = try container.decode(WorkspaceState.self, forKey: .workspace)
        self.parentID = try container.decodeIfPresent(UUID.self, forKey: .parentID)
        self.layout = try? container.decodeIfPresent(SplitLayout.self, forKey: .layout)
        self.liveTitle = nil
        self.liveDirectory = nil
    }

    public static func == (lhs: TerminalSession, rhs: TerminalSession) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.title == rhs.title
            && lhs.header == rhs.header
            && lhs.agent == rhs.agent
            && lhs.url == rhs.url
            && lhs.workspace == rhs.workspace
            && lhs.parentID == rhs.parentID
            && lhs.layout == rhs.layout
    }
}
