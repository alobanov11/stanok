import Foundation
import Testing

import StanokKit

struct GitStatusParserTests {

    private enum Fixture {

        enum ExtraFixture {

            static let mmChunks = [
                "1 MM N... 100644 100644 100644 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "ce0ae89675a3f1a790d6491a53694670db2c8d57 file.txt"
            ]

            static let rmChunks = [
                "2 RM N... 100644 100644 100644 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "df967b96a579e45a18b8251732d16804b2e56a55 R100 new.txt",
                "old.txt"
            ]

            static let adChunks = [
                "1 AD N... 000000 100644 000000 "
                    + "0000000000000000000000000000000000000000 "
                    + "3e757656cf36eca53338e520d134963a44f793f8 added.txt"
            ]

            static let rdChunks = [
                "2 RD N... 100644 100644 000000 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "df967b96a579e45a18b8251732d16804b2e56a55 R100 new.txt",
                "old.txt"
            ]

            static let syntheticCopyDeletedChunks = [
                "2 CD N... 100644 100644 000000 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "df967b96a579e45a18b8251732d16804b2e56a55 C100 copy.txt",
                "source.txt"
            ]

            static let syntheticCopyChunks = [
                "2 C. N... 100644 100644 100644 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "df967b96a579e45a18b8251732d16804b2e56a55 C100 copy2.txt",
                "source2.txt"
            ]

            static let danglingRenameChunks = [
                "2 R. N... 100644 100644 100644 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "df967b96a579e45a18b8251732d16804b2e56a55 R100 dangling.txt"
            ]

            static let truncatedOrdinaryChunks = [
                "1 MM N... 100644 100644 truncated.txt"
            ]

            static let malformedTagChunks = [
                "1x XY N... 100644 100644 100644 df967b96a579e45a18b8251732d16804b2e56a55 "
                    + "3e757656cf36eca53338e520d134963a44f793f8 ghost.txt"
            ]

            static let invalidUtf8TargetPath: Data = {
                var chunk = Data(
                    "2 R. N... 100644 100644 100644 df967b96a579e45a18b8251732d16804b2e56a55 "
                        .utf8
                )
                chunk.append(Data("df967b96a579e45a18b8251732d16804b2e56a55 R100 bad".utf8))
                chunk.append(contentsOf: [0xFF, 0xFE])
                chunk.append(Data("name.txt".utf8))
                return chunk
            }()

            static let invalidUtf8OriginalPath = Data("? victim.txt".utf8)
            static let invalidUtf8SentinelChunk = Data("? sentinel.txt".utf8)
        }

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

        static func rawData(from chunks: [Data]) -> Data {
            var result = Data()
            for chunk in chunks {
                result.append(chunk)
                result.append(0x00)
            }
            return result
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

    @Test
    func parsesStagedModificationWithFurtherWorktreeChange() {
        let changes = GitStatusParser.parse(Fixture.data(from: Fixture.ExtraFixture.mmChunks))
        let change = changes.first { $0.path == "file.txt" }

        #expect(change?.status == .modified)
        #expect(change?.indexStatus == "M")
        #expect(change?.worktreeStatus == "M")
    }

    @Test
    func parsesRenameWithFurtherWorktreeChange() {
        let changes = GitStatusParser.parse(Fixture.data(from: Fixture.ExtraFixture.rmChunks))
        let change = changes.first { $0.path == "new.txt" }

        #expect(change?.status == .renamed)
        #expect(change?.originalPath == "old.txt")
        #expect(change?.indexStatus == "R")
        #expect(change?.worktreeStatus == "M")
    }

    @Test
    func parsesStagedAdditionDeletedFromWorktree() {
        let changes = GitStatusParser.parse(Fixture.data(from: Fixture.ExtraFixture.adChunks))
        let change = changes.first { $0.path == "added.txt" }

        #expect(change?.status == .deleted)
        #expect(change?.indexStatus == "A")
        #expect(change?.worktreeStatus == "D")
    }

    @Test
    func parsesRenameDeletedFromWorktree() {
        let changes = GitStatusParser.parse(Fixture.data(from: Fixture.ExtraFixture.rdChunks))
        let change = changes.first { $0.path == "new.txt" }

        #expect(change?.status == .deleted)
        #expect(change?.originalPath == "old.txt")
        #expect(change?.indexStatus == "R")
        #expect(change?.worktreeStatus == "D")
    }

    @Test
    func parsesCopyDeletedFromWorktree() {
        let chunks = Fixture.ExtraFixture.syntheticCopyDeletedChunks
        let changes = GitStatusParser.parse(Fixture.data(from: chunks))
        let change = changes.first { $0.path == "copy.txt" }

        #expect(change?.status == .deleted)
        #expect(change?.originalPath == "source.txt")
        #expect(change?.indexStatus == "C")
        #expect(change?.worktreeStatus == "D")
    }

    @Test
    func parsesPureCopy() {
        let changes = GitStatusParser.parse(
            Fixture.data(from: Fixture.ExtraFixture.syntheticCopyChunks)
        )
        let change = changes.first { $0.path == "copy2.txt" }

        #expect(change?.status == .copied)
        #expect(change?.originalPath == "source2.txt")
        #expect(change?.indexStatus == "C")
    }

    @Test
    func parsesDanglingRenameWithoutOriginalPathChunk() {
        let chunks = Fixture.ExtraFixture.danglingRenameChunks
        let changes = GitStatusParser.parse(Fixture.data(from: chunks))

        #expect(changes.count == 1)
        #expect(changes.first?.path == "dangling.txt")
        #expect(changes.first?.originalPath == nil)
    }

    @Test
    func rejectsTruncatedOrdinaryLine() {
        let chunks = Fixture.ExtraFixture.truncatedOrdinaryChunks
        let changes = GitStatusParser.parse(Fixture.data(from: chunks))

        #expect(changes.isEmpty)
    }

    @Test
    func rejectsMalformedTag() {
        let chunks = Fixture.ExtraFixture.malformedTagChunks
        let changes = GitStatusParser.parse(Fixture.data(from: chunks))

        #expect(changes.isEmpty)
    }

    @Test
    func invalidUtf8RenameTargetDoesNotDesyncTheStream() {
        let changes = GitStatusParser.parse(Fixture.rawData(from: [
            Fixture.ExtraFixture.invalidUtf8TargetPath,
            Fixture.ExtraFixture.invalidUtf8OriginalPath,
            Fixture.ExtraFixture.invalidUtf8SentinelChunk
        ]))

        #expect(changes.count == 2)
        #expect(changes.contains { $0.path == "sentinel.txt" })
        #expect(!changes.contains { $0.path == "victim.txt" })
        #expect(changes.first { $0.status == .renamed }?.originalPath == "? victim.txt")
    }
}
