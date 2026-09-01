import Foundation
import Testing

import StanokKit

struct GitBranchRefParserTests {

    private enum Fixture {

        static let kitchenSinkLines = [
            "refs/heads/bugfix/bar\u{0}\u{0} ",
            "refs/heads/feature/foo\u{0}\u{0} ",
            "refs/heads/main\u{0}\u{0}*",
            "refs/remotes/origin/HEAD\u{0}refs/remotes/origin/main\u{0} ",
            "refs/remotes/origin/feature/foo\u{0}\u{0} ",
            "refs/remotes/origin/main\u{0}\u{0} ",
            "refs/remotes/upstream/HEAD\u{0}refs/remotes/upstream/main\u{0} ",
            "refs/remotes/upstream/main\u{0}\u{0} "
        ]

        static let truncatedLine = "refs/heads/broken\u{0} "

        static let unknownPrefixLine = "refs/tags/v1.0.0\u{0}\u{0} "

        static func data(from lines: [String]) -> Data {
            Data((lines.joined(separator: "\n") + "\n").utf8)
        }
    }

    private static let kitchenSink = GitBranchRefParser.parse(
        Fixture.data(from: Fixture.kitchenSinkLines)
    )

    @Test
    func skipsSymbolicRemoteHead() {
        #expect(!Self.kitchenSink.contains { $0.fullName == "refs/remotes/origin/HEAD" })
        #expect(!Self.kitchenSink.contains { $0.fullName == "refs/remotes/upstream/HEAD" })
    }

    @Test
    func marksCurrentLocalBranch() {
        let main = Self.kitchenSink.first { $0.fullName == "refs/heads/main" }

        #expect(main?.isCurrent == true)
        #expect(main?.kind == .local)
        #expect(main?.displayName == "main")
    }

    @Test
    func marksNonCurrentLocalBranches() {
        let feature = Self.kitchenSink.first { $0.fullName == "refs/heads/feature/foo" }
        let bugfix = Self.kitchenSink.first { $0.fullName == "refs/heads/bugfix/bar" }

        #expect(feature?.isCurrent == false)
        #expect(feature?.displayName == "feature/foo")
        #expect(bugfix?.isCurrent == false)
    }

    @Test
    func splitsRemoteNameFromNestedDisplayName() {
        let ref = Self.kitchenSink.first { $0.fullName == "refs/remotes/origin/feature/foo" }

        #expect(ref?.kind == .remote)
        #expect(ref?.remoteName == "origin")
        #expect(ref?.displayName == "feature/foo")
    }

    @Test
    func groupsRefsAcrossMultipleRemotes() {
        let origin = Self.kitchenSink.filter { $0.remoteName == "origin" }
        let upstream = Self.kitchenSink.filter { $0.remoteName == "upstream" }

        #expect(origin.count == 2)
        #expect(upstream.count == 1)
    }

    @Test
    func totalRefCountExcludesSymrefs() {
        #expect(Self.kitchenSink.count == 6)
    }

    @Test
    func skipsTruncatedLine() {
        let changes = GitBranchRefParser.parse(Fixture.data(from: [Fixture.truncatedLine]))

        #expect(changes.isEmpty)
    }

    @Test
    func skipsUnknownRefPrefix() {
        let changes = GitBranchRefParser.parse(Fixture.data(from: [Fixture.unknownPrefixLine]))

        #expect(changes.isEmpty)
    }
}
