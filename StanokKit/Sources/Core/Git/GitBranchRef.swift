import Foundation

public struct GitBranchRef: Identifiable, Equatable, Sendable {

    public enum Kind: Equatable, Sendable {

        case local
        case remote
    }

    public var id: String {
        fullName
    }

    public let fullName: String
    public let displayName: String
    public let kind: Kind
    public let remoteName: String?
    public let isCurrent: Bool
    public let occupyingWorktreePath: String?

    public init(
        fullName: String,
        displayName: String,
        kind: Kind,
        remoteName: String? = nil,
        isCurrent: Bool = false,
        occupyingWorktreePath: String? = nil
    ) {
        self.fullName = fullName
        self.displayName = displayName
        self.kind = kind
        self.remoteName = remoteName
        self.isCurrent = isCurrent
        self.occupyingWorktreePath = occupyingWorktreePath
    }

    func withOccupancy(_ path: String?) -> GitBranchRef {
        GitBranchRef(
            fullName: fullName,
            displayName: displayName,
            kind: kind,
            remoteName: remoteName,
            isCurrent: isCurrent,
            occupyingWorktreePath: path
        )
    }
}
