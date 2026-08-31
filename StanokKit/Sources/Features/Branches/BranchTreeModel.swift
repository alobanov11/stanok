import Foundation

@MainActor
@Observable
final class BranchTreeModel {

    var listError: String? { snapshot?.listError }
    var worktreeError: String? { snapshot?.worktreeError }
    var isLoaded: Bool { snapshot != nil }
    var isRepository: Bool { snapshot?.root != nil }
    var isEmpty: Bool { snapshot?.refs.isEmpty ?? true }

    private(set) var root: BranchNode?

    private var snapshot: GitBranchSnapshot?

    func apply(_ snapshot: GitBranchSnapshot?) {
        self.snapshot = snapshot
        root = snapshot.map { BranchTreeBuilder.build(from: $0.refs, reusing: root) }
    }
}
