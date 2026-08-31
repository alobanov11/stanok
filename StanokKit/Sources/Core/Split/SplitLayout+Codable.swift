import Foundation

extension SplitLayout: Codable {

    private enum CodingKeys: String, CodingKey {

        case leaf
        case axis
        case children
    }

    private enum LegacyCase: String, CodingKey {

        case leaf
        case split
    }

    private enum LegacyPayload: String, CodingKey {

        case first = "_0"
        case second = "_1"
        case third = "_2"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let id = try? container.decode(UUID.self, forKey: .leaf) {
            self = .leaf(id)
            return
        }

        if
            let axis = try? container.decode(SplitAxis.self, forKey: .axis),
            let children = try? container.decode([SplitLayout].self, forKey: .children) {
            self = .split(axis, children)
            return
        }

        self = try Self.decodedFromPairs(decoder)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .leaf(id):
            try container.encode(id, forKey: .leaf)

        case let .split(axis, children):
            try container.encode(axis, forKey: .axis)
            try container.encode(children, forKey: .children)
        }
    }

    private static func decodedFromPairs(_ decoder: any Decoder) throws -> SplitLayout {
        let container = try decoder.container(keyedBy: LegacyCase.self)

        if
            let leaf = try? container.nestedContainer(keyedBy: LegacyPayload.self, forKey: .leaf),
            let id = try? leaf.decode(UUID.self, forKey: .first) {
            return .leaf(id)
        }

        let split = try container.nestedContainer(keyedBy: LegacyPayload.self, forKey: .split)

        return try .split(
            split.decode(SplitAxis.self, forKey: .first),
            [
                split.decode(SplitLayout.self, forKey: .second),
                split.decode(SplitLayout.self, forKey: .third)
            ]
        )
    }
}
