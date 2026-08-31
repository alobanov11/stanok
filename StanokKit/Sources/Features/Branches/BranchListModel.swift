import Foundation

@MainActor
@Observable
final class BranchListModel {

    var localMatches: [GitBranchRef] {
        GitBranchGrouping.localMatches(refs, search: searchText)
    }

    var remoteGroups: [GitBranchGrouping.RemoteGroup] {
        GitBranchGrouping.remoteGroups(refs, search: searchText)
    }

    var listError: String? { snapshot?.listError }

    var worktreeError: String? { snapshot?.worktreeError }

    var isLoaded: Bool { snapshot != nil }

    var isEmpty: Bool { refs.isEmpty }

    private var refs: [GitBranchRef] { snapshot?.refs ?? [] }

    var searchText = ""

    private var snapshot: GitBranchSnapshot?

    func apply(_ snapshot: GitBranchSnapshot?) {
        self.snapshot = snapshot
    }
}
