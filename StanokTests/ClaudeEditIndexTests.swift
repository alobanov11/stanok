import Foundation
import Testing

@testable import StanokAgents
@testable import StanokKit

struct ClaudeEditIndexTests {

    private static func makeRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "claude-index-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func record(_ file: String, at stamp: String) -> String {
        """
        {"cwd":"/Users/tom/Projects/app","timestamp":"\(stamp)","message":{"content":\
        [{"type":"tool_use","name":"Edit","input":{"file_path":"\(file)"}}]}}
        """
    }

    @Test
    func editedPathsAndTheWorkingDirectoryComeFromTheLog() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = root.appending(path: "session.jsonl")
        let line = Self.record("/Users/tom/Projects/app/main.swift", at: "2026-09-01T10:00:00.000Z")
        try (line + "\n").write(to: log, atomically: true, encoding: .utf8)

        let found = await ClaudeEditIndex().touched(under: root)

        #expect(found.1 == ["/Users/tom/Projects/app"])
        #expect(found.0.map(\.url.lastPathComponent) == ["main.swift"])
    }

    @Test
    func anUnfinishedLastLineIsPickedUpAfterItIsCompleted() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = root.appending(path: "session.jsonl")
        let first = Self.record("/Users/tom/Projects/app/one.swift", at: "2026-09-01T10:00:00.000Z")
        let second = Self.record("/Users/tom/Projects/app/two.swift", at: "2026-09-01T11:00:00.000Z")

        try (first + "\n" + String(second.prefix(40))).write(
            to: log, atomically: true, encoding: .utf8
        )

        let index = ClaudeEditIndex()
        let partial = await index.touched(under: root)
        #expect(partial.0.map(\.url.lastPathComponent) == ["one.swift"])

        try (first + "\n" + second + "\n").write(to: log, atomically: true, encoding: .utf8)

        let complete = await index.touched(under: root)
        #expect(Set(complete.0.map(\.url.lastPathComponent)) == ["one.swift", "two.swift"])
    }

    @Test
    func aTruncatedLogIsReadFromTheStartAgain() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let log = root.appending(path: "session.jsonl")
        let old = Self.record("/Users/tom/Projects/app/old.swift", at: "2026-09-01T10:00:00.000Z")
        try (old + "\n").write(to: log, atomically: true, encoding: .utf8)

        let index = ClaudeEditIndex()
        _ = await index.touched(under: root)

        let fresh = Self.record("/Users/tom/Projects/app/new.swift", at: "2026-09-01T12:00:00.000Z")
        try (fresh + "\n").write(to: log, atomically: true, encoding: .utf8)

        let found = await index.touched(under: root)

        #expect(found.0.map(\.url.lastPathComponent) == ["new.swift"])
    }
}
