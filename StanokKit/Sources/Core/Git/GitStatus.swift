import Foundation

public struct GitStatus: Equatable, Sendable {

    public var hasChanges: Bool {
        added > 0 || removed > 0 || isDirty
    }

    public let branch: String?
    public let added: Int
    public let removed: Int
    public let isDirty: Bool
    public let tracking: GitTracking

    public init(
        branch: String?,
        added: Int,
        removed: Int,
        isDirty: Bool = false,
        tracking: GitTracking = .none
    ) {
        self.branch = branch
        self.added = added
        self.removed = removed
        self.isDirty = isDirty
        self.tracking = tracking
    }
}
