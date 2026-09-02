import Foundation

public indirect enum SplitLayout: Equatable, Sendable {

    case leaf(UUID)
    case split(SplitAxis, [SplitLayout])

    public var leafIDs: [UUID] {
        switch self {
        case let .leaf(id):
            [id]

        case let .split(_, children):
            children.flatMap(\.leafIDs)
        }
    }

    public func contains(_ id: UUID) -> Bool {
        leafIDs.contains(id)
    }
}
