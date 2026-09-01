import Foundation

public enum ReviewSource: Sendable, Equatable {

    case worktree
    case commit(String)

    public var key: String {
        switch self {
        case .worktree: "worktree"
        case let .commit(sha): sha
        }
    }
}
