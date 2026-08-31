import Foundation

public struct GitWorktreeEntry: Equatable, Sendable {

    public let path: String
    public let branchFullName: String?

    public init(path: String, branchFullName: String? = nil) {
        self.path = path
        self.branchFullName = branchFullName
    }
}
