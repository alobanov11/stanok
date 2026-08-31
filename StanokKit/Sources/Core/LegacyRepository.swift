import Foundation

struct LegacyRepository: Decodable {

    private enum CodingKeys: String, CodingKey {

        case id
        case url
        case sessions
        case lastOpenedAt
        case workspace
    }

    let id: UUID

    let url: URL

    let sessions: [LegacySession]

    let lastOpenedAt: Date

    let workspace: LegacyWorkspaceState

    init(
        id: UUID,
        url: URL,
        sessions: [LegacySession],
        lastOpenedAt: Date,
        workspace: LegacyWorkspaceState = LegacyWorkspaceState()
    ) {
        self.id = id
        self.url = url
        self.sessions = sessions
        self.lastOpenedAt = lastOpenedAt
        self.workspace = workspace
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.url = try container.decode(URL.self, forKey: .url)
        self.sessions = try container.decode([LegacySession].self, forKey: .sessions)
        self.lastOpenedAt = try container.decode(Date.self, forKey: .lastOpenedAt)
        self.workspace = try container.decodeIfPresent(
            LegacyWorkspaceState.self,
            forKey: .workspace
        ) ?? LegacyWorkspaceState()
    }
}
