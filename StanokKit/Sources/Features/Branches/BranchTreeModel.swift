import Foundation

@MainActor
@Observable
final class BranchTreeModel {

    enum State {

        case loading
        case notRepository
        case empty
        case loaded
    }

    var listError: String? {
        snapshot?.listError
    }

    var worktreeError: String? {
        snapshot?.worktreeError
    }

    var state: State {
        guard let snapshot else { return .loading }
        guard snapshot.root != nil else { return .notRepository }

        return snapshot.refs.isEmpty ? .empty : .loaded
    }

    private(set) var root: BranchNode?

    private var snapshot: GitBranchSnapshot?

    func apply(_ snapshot: GitBranchSnapshot?) {
        self.snapshot = snapshot
        root = snapshot.map { BranchTreeBuilder.build(from: $0.refs, reusing: root) }
    }
}
