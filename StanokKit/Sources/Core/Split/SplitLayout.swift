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

    public func inserting(
        _ id: UUID,
        _ direction: SplitDirection,
        near target: UUID
    ) -> SplitLayout {
        switch self {
        case let .leaf(existing):
            guard existing == target else { return self }

            return .split(
                direction.axis,
                direction.insertsFirst ? [.leaf(id), self] : [self, .leaf(id)]
            )

        case let .split(axis, children):
            guard
                axis == direction.axis,
                let slot = children.firstIndex(of: .leaf(target))
            else {
                return .split(axis, children.map { $0.inserting(id, direction, near: target) })
            }

            var siblings = children
            siblings.insert(.leaf(id), at: direction.insertsFirst ? slot : slot + 1)
            return .split(axis, siblings)
        }
    }

    public func removing(_ id: UUID) -> SplitLayout? {
        switch self {
        case let .leaf(existing):
            return existing == id ? nil : self

        case let .split(axis, children):
            let survivors = children.compactMap { $0.removing(id) }

            switch survivors.count {
            case 0: return nil
            case 1: return survivors[0]
            default: return .split(axis, survivors)
            }
        }
    }
}
