import Foundation
import Testing

import StanokKit

struct GitStatusParserTests {

    private enum Fixture {

        static let kitchenSinkChunks = [
            "1 A. N... 000000 100644 100644 0000000000000000000000000000000000000000 "
                + "32ea4473758476d686292e67c39963098719f287 .gitmodules",
            "1 A. N... 000000 100644 100644 0000000000000000000000000000000000000000 "
                + "956231d8d85cc4e6d955dad969daa86a12250729 added.txt",
            "1 M. N... 100644 100644 100644 c0d0fb45c382919737f8d0c20aaf57cf89b74af8 "
                + "83db48f84ec878fbfb30b46d16630e944e34f205 base.txt",
            "1 .D N... 100644 100644 000000 420201136f42027c6f971934cc73615082d65160 "
                + "420201136f42027c6f971934cc73615082d65160 gone.txt",
            "2 R. N... 100644 100644 100644 c9ea4b82177d3bbe66f340e517f56dcb2e4eb691 "
                + "c9ea4b82177d3bbe66f340e517f56dcb2e4eb691 R100 renamed.txt",
            "old-name.txt",
            "1 A. S... 000000 160000 160000 0000000000000000000000000000000000000000 "
                + "e02a110619a84baaceb925e60ea7bc32af7abdec sub",
            "? has space.txt",
            "? has\"quote.txt",
            "? untracked.txt",
            "? новый файл.txt"
        ]

        static let conflictChunks = [
            "u UU N... 100644 100644 100644 100644 "
                + "df967b96a579e45a18b8251732d16804b2e56a55 "
                + "83b95016c6942d97523e8147fc8240122c59e4aa "
                + "0b355047172447d449b93c13166660c26a715550 conflict.txt"
        ]

        static func data(from chunks: [String]) -> Data {
            Data((chunks.joined(separator: "\0") + "\0").utf8)
        }
    }

    private static let kitchenSink = GitStatusParser.parse(
        Fixture.data(from: Fixture.kitchenSinkChunks)
    )

    private static let conflict = GitStatusParser.parse(Fixture.data(from: Fixture.conflictChunks))

    @Test
    func parsesRenameWithOriginalPath() {
        let change = Self.kitchenSink.first { $0.path == "renamed.txt" }

        #expect(change?.status == .renamed)
        #expect(change?.originalPath == "old-name.txt")
        #expect(change?.isSubmodule == false)
    }

    @Test
    func parsesConflict() {
        #expect(Self.conflict.count == 1)
        #expect(Self.conflict.first?.path == "conflict.txt")
        #expect(Self.conflict.first?.status == .conflicted)
    }

    @Test
    func parsesSubmodule() {
        let change = Self.kitchenSink.first { $0.path == "sub" }

        #expect(change?.status == .added)
        #expect(change?.isSubmodule == true)
    }

    @Test
    func parsesCyrillicUntrackedPath() {
        let change = Self.kitchenSink.first { $0.path == "новый файл.txt" }

        #expect(change?.status == .untracked)
    }

    @Test
    func parsesQuotedUntrackedPath() {
        let change = Self.kitchenSink.first { $0.path == "has\"quote.txt" }

        #expect(change?.status == .untracked)
    }

    @Test
    func parsesSpacedUntrackedPath() {
        let change = Self.kitchenSink.first { $0.path == "has space.txt" }

        #expect(change?.status == .untracked)
    }

    @Test
    func parsesPlainUntrackedPath() {
        let change = Self.kitchenSink.first { $0.path == "untracked.txt" }

        #expect(change?.status == .untracked)
    }

    @Test
    func parsesUnstagedDeletion() {
        let change = Self.kitchenSink.first { $0.path == "gone.txt" }

        #expect(change?.status == .deleted)
    }

    @Test
    func parsesStagedAdditionAndModification() {
        let added = Self.kitchenSink.first { $0.path == "added.txt" }
        let modified = Self.kitchenSink.first { $0.path == "base.txt" }

        #expect(added?.status == .added)
        #expect(modified?.status == .modified)
    }

    @Test
    func parsesEntryCount() {
        #expect(Self.kitchenSink.count == 10)
    }
}
