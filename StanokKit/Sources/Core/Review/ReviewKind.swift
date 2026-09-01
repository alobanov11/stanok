import Foundation

public enum ReviewKind: Sendable, Equatable {

    case git
    case branch(root: String, ref: String, name: String)

    public var key: String {
        switch self {
        case .git: "git"
        case let .branch(root, ref, _): "branch:" + root + ":" + ref
        }
    }

    public var title: String {
        switch self {
        case .git: "Изменения"
        case let .branch(_, _, name): name
        }
    }
}
