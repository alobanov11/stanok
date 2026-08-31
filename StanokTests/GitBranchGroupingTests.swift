import Foundation
import Testing

import StanokKit

struct GitBranchGroupingTests {

    private enum Fixture {

        static let refs = [
            GitBranchRef(
                fullName: "refs/heads/main",
                displayName: "main",
                kind: .local,
                isCurrent: true
            ),
            GitBranchRef(
                fullName: "refs/heads/feature/foo",
                displayName: "feature/foo",
                kind: .local
            ),
            GitBranchRef(
                fullName: "refs/remotes/origin/main",
                displayName: "main",
                kind: .remote,
                remoteName: "origin"
            ),
            GitBranchRef(
                fullName: "refs/remotes/origin/feature/foo",
                displayName: "feature/foo",
                kind: .remote,
                remoteName: "origin"
            ),
            GitBranchRef(
                fullName: "refs/remotes/upstream/main",
                displayName: "main",
                kind: .remote,
                remoteName: "upstream"
            )
        ]
    }

    @Test
    func localMatchesExcludesRemoteRefs() {
        let locals = GitBranchGrouping.localMatches(Fixture.refs, search: "")

        #expect(locals.count == 2)
        #expect(locals.allSatisfy { $0.kind == .local })
    }

    @Test
    func remoteGroupsByRemoteName() {
        let groups = GitBranchGrouping.remoteGroups(Fixture.refs, search: "")

        #expect(groups.map(\.name) == ["origin", "upstream"])
        #expect(groups.first { $0.name == "origin" }?.refs.count == 2)
        #expect(groups.first { $0.name == "upstream" }?.refs.count == 1)
    }

    @Test
    func searchFiltersByFullNameCaseInsensitively() {
        let locals = GitBranchGrouping.localMatches(Fixture.refs, search: "FEATURE")

        #expect(locals.count == 1)
        #expect(locals.first?.fullName == "refs/heads/feature/foo")
    }

    @Test
    func searchFiltersRemoteGroupsAndDropsEmptyGroups() {
        let groups = GitBranchGrouping.remoteGroups(Fixture.refs, search: "upstream")

        #expect(groups.map(\.name) == ["upstream"])
    }

    @Test
    func searchMatchesAgainstFullNameNotJustDisplayName() {
        let locals = GitBranchGrouping.localMatches(Fixture.refs, search: "refs/heads")

        #expect(locals.count == 2)
    }

    @Test
    func searchWithNoMatchesReturnsEmpty() {
        let locals = GitBranchGrouping.localMatches(Fixture.refs, search: "nonexistent")
        let groups = GitBranchGrouping.remoteGroups(Fixture.refs, search: "nonexistent")

        #expect(locals.isEmpty)
        #expect(groups.isEmpty)
    }
}
