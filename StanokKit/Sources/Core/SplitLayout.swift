import Foundation

public indirect enum SplitLayout: Equatable, Codable, Sendable {

    case leaf(UUID)
    case split(SplitAxis, SplitLayout, SplitLayout)

    public var leafIDs: [UUID] {
        switch self {
        case let .leaf(id):
            [id]

        case let .split(_, first, second):
            first.leafIDs + second.leafIDs
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

            return direction.insertsFirst
                ? .split(direction.axis, .leaf(id), self)
                : .split(direction.axis, self, .leaf(id))

        case let .split(axis, first, second):
            return .split(
                axis,
                first.inserting(id, direction, near: target),
                second.inserting(id, direction, near: target)
            )
        }
    }

    public func removing(_ id: UUID) -> SplitLayout? {
        switch self {
        case let .leaf(existing):
            return existing == id ? nil : self

        case let .split(axis, first, second):
            switch (first.removing(id), second.removing(id)) {
            case (nil, nil):
                return nil

            case let (survivor?, nil), let (nil, survivor?):
                return survivor

            case let (left?, right?):
                return .split(axis, left, right)
            }
        }
    }
}
