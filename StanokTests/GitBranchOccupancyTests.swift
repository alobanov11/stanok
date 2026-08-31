import Foundation
import Testing

import StanokKit

struct GitBranchOccupancyTests {

    private enum Fixture {

        static let currentRoot = "/Users/tom/Projects/sorok"

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
                fullName: "refs/heads/bugfix/bar",
                displayName: "bugfix/bar",
                kind: .local
            )
        ]

        static let worktrees = [
            GitWorktreeEntry(path: currentRoot, branchFullName: "refs/heads/main"),
            GitWorktreeEntry(
                path: "/Users/tom/Projects/sorok-wt-feature",
                branchFullName: "refs/heads/feature/foo"
            ),
            GitWorktreeEntry(path: "/Users/tom/Projects/sorok-wt-detached", branchFullName: nil)
        ]
    }

    private static let merged = GitBranchOccupancy.apply(
        Fixture.refs,
        worktrees: Fixture.worktrees,
        currentRoot: Fixture.currentRoot
    )

    @Test
    func doesNotMarkCurrentWorktreesBranchAsOccupied() {
        let main = Self.merged.first { $0.fullName == "refs/heads/main" }

        #expect(main?.occupyingWorktreePath == nil)
    }

    @Test
    func marksBranchCheckedOutInAnotherWorktree() {
        let feature = Self.merged.first { $0.fullName == "refs/heads/feature/foo" }

        #expect(feature?.occupyingWorktreePath == "/Users/tom/Projects/sorok-wt-feature")
    }

    @Test
    func leavesUnrelatedBranchUnoccupied() {
        let bugfix = Self.merged.first { $0.fullName == "refs/heads/bugfix/bar" }

        #expect(bugfix?.occupyingWorktreePath == nil)
    }

    @Test
    func normalizesTrailingSlashOnCurrentRoot() {
        let merged = GitBranchOccupancy.apply(
            Fixture.refs,
            worktrees: Fixture.worktrees,
            currentRoot: Fixture.currentRoot + "/"
        )
        let main = merged.first { $0.fullName == "refs/heads/main" }

        #expect(main?.occupyingWorktreePath == nil)
    }
}
