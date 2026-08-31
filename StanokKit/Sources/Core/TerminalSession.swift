import Foundation

public struct TerminalSession: Identifiable, Codable, Equatable {

    private enum CodingKeys: String, CodingKey {

        case id
        case name
        case isPinned
        case isAgentsExpanded
    }

    public let id: UUID

    public var name: String

    public var isPinned: Bool

    public var isAgentsExpanded: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        isPinned: Bool = false,
        isAgentsExpanded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isPinned = isPinned
        self.isAgentsExpanded = isAgentsExpanded
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.isAgentsExpanded = try container
            .decodeIfPresent(Bool.self, forKey: .isAgentsExpanded) ?? false
    }
}
