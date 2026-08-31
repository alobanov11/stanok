import Foundation

public struct GitBranchSnapshot: Equatable, Sendable {

    public let refs: [GitBranchRef]
    public let root: String?
    public let listError: String?
    public let worktreeError: String?

    public init(
        refs: [GitBranchRef],
        root: String? = nil,
        listError: String? = nil,
        worktreeError: String? = nil
    ) {
        self.refs = refs
        self.root = root
        self.listError = listError
        self.worktreeError = worktreeError
    }
}
