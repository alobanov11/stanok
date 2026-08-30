import Foundation

public struct GitChange: Equatable, Sendable {

    public let path: String

    public let originalPath: String?

    public let status: GitFileStatus

    public let isSubmodule: Bool

    public let added: Int?

    public let removed: Int?

    public init(
        path: String,
        originalPath: String? = nil,
        status: GitFileStatus,
        isSubmodule: Bool = false,
        added: Int? = nil,
        removed: Int? = nil
    ) {
        self.path = path
        self.originalPath = originalPath
        self.status = status
        self.isSubmodule = isSubmodule
        self.added = added
        self.removed = removed
    }
}
