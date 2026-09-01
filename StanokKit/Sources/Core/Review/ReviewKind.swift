import Foundation

public enum ReviewKind: Sendable, Equatable {

    case git
    case commit(root: String, sha: String, subject: String)

    public var key: String {
        switch self {
        case .git: "git"
        case let .commit(root, sha, _): "commit:" + root + ":" + sha
        }
    }

    public var title: String {
        switch self {
        case .git: "Изменения"
        case let .commit(_, sha, subject):
            subject.isEmpty ? "Коммит \(sha.prefix(7))" : "\(sha.prefix(7)) · \(subject)"
        }
    }
}
