import Foundation
import Testing

@testable import StanokKit

struct GitCommitParserTests {

    @Test
    func aLogWithTwoCommitsKeepsOrderStatusesAndRenames() throws {
        let log = record(
            sha: "a1",
            subject: "первый",
            entries: ["\nA", "Sources/New.swift", "R100", "Old.swift", "Sources/Moved.swift"]
        ) + record(
            sha: "b2",
            subject: "второй",
            entries: ["\nD", "Gone.swift", "M", "Sources/Same.swift"]
        )

        let commits = GitCommitParser.commits(log)

        #expect(commits.map(\.sha) == ["a1", "b2"])
        #expect(commits[0].subject == "первый")
        #expect(commits[0].changes.map(\.path) == ["Sources/Moved.swift", "Sources/New.swift"])
        #expect(commits[0].changes.first?.status == .renamed)
        #expect(commits[0].changes.first?.originalPath == "Old.swift")
        #expect(commits[1].changes.map(\.status) == [.deleted, .modified])
    }

    @Test
    func aTruncatedRenameIsDroppedInsteadOfShiftingTheStream() throws {
        let log = record(sha: "c3", subject: "обрыв", entries: ["\nM", "A.swift", "R100", "Old.swift"])

        let commits = GitCommitParser.commits(log)

        #expect(commits.count == 1)
        #expect(commits[0].changes.map(\.path) == ["A.swift"])
    }

    private func record(sha: String, subject: String, entries: [String]) -> Data {
        var data = Data("\u{1e}\(sha)\u{1f}\(subject)\u{1f}".utf8)
        data.append(0)

        for entry in entries {
            data.append(contentsOf: Array(entry.utf8))
            data.append(0)
        }

        return data
    }
}
