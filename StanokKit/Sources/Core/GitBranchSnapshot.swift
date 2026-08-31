import Foundation

public struct GitBranchSnapshot: Equatable, Sendable {

    public let refs: [GitBranchRef]

    public let listError: String?

    public let worktreeError: String?

    public init(refs: [GitBranchRef], listError: String? = nil, worktreeError: String? = nil) {
        self.refs = refs
        self.listError = listError
        self.worktreeError = worktreeError
    }
}
