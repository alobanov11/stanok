import Foundation
import Testing

import StanokKit

struct GitWorktreeListParserTests {

    private enum Fixture {

        static let threeWorktrees: [[String]] = [
            [
                "worktree /Users/tom/Projects/sorok",
                "HEAD d46fbed503709094a1f16bf563f8f841a0cd8f2d",
                "branch refs/heads/main"
            ],
            [
                "worktree /Users/tom/Projects/sorok-wt-feature",
                "HEAD d46fbed503709094a1f16bf563f8f841a0cd8f2d",
                "branch refs/heads/feature/foo"
            ],
            [
                "worktree /Users/tom/Projects/sorok-wt-detached",
                "HEAD d46fbed503709094a1f16bf563f8f841a0cd8f2d",
                "detached",
                "locked testing"
            ]
        ]

        static func data(from entries: [[String]]) -> Data {
            var raw = ""
            for entry in entries {
                raw += entry.joined(separator: "\u{0}") + "\u{0}\u{0}"
            }
            return Data(raw.utf8)
        }
    }

    private static let parsed = GitWorktreeListParser.parse(
        Fixture.data(from: Fixture.threeWorktrees)
    )

    @Test
    func parsesEntryCount() {
        #expect(Self.parsed.count == 3)
    }

    @Test
    func parsesPathAndBranchForOrdinaryWorktree() {
        let main = Self.parsed.first { $0.path == "/Users/tom/Projects/sorok" }

        #expect(main?.branchFullName == "refs/heads/main")
    }

    @Test
    func parsesLinkedWorktreeBranch() {
        let feature = Self.parsed.first { $0.path == "/Users/tom/Projects/sorok-wt-feature" }

        #expect(feature?.branchFullName == "refs/heads/feature/foo")
    }

    @Test
    func detachedLockedWorktreeHasNoBranch() {
        let detached = Self.parsed.first { $0.path == "/Users/tom/Projects/sorok-wt-detached" }

        #expect(detached?.branchFullName == nil)
    }

    @Test
    func handlesEmptyInput() {
        let changes = GitWorktreeListParser.parse(Data())

        #expect(changes.isEmpty)
    }

    @Test
    func ignoresGarbageBeforeFirstWorktreeLine() {
        let garbage = Fixture.data(from: [["not-a-worktree-line", "branch refs/heads/orphan"]])
        let changes = GitWorktreeListParser.parse(garbage)

        #expect(changes.isEmpty)
    }
}
