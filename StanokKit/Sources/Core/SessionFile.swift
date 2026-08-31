import Foundation

public struct SessionFile: Codable, Equatable {

    private enum CodingKeys: String, CodingKey {

        case sessions
        case selectedSessionID
    }

    public var sessions: [TerminalSession]
    public var selectedSessionID: TerminalSession.ID?

    public init(sessions: [TerminalSession], selectedSessionID: TerminalSession.ID? = nil) {
        self.sessions = sessions
        self.selectedSessionID = selectedSessionID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessions = try container.decode([TerminalSession].self, forKey: .sessions)
        self.selectedSessionID = try container.decodeIfPresent(
            TerminalSession.ID.self,
            forKey: .selectedSessionID
        )
    }
}
