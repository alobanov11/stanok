import Foundation

public struct GitStatus: Equatable, Sendable {

    public var hasChanges: Bool { added > 0 || removed > 0 }

    public let branch: String?
    public let added: Int
    public let removed: Int
    public let tracking: GitTracking

    public init(branch: String?, added: Int, removed: Int, tracking: GitTracking = .none) {
        self.branch = branch
        self.added = added
        self.removed = removed
        self.tracking = tracking
    }
}
