import Foundation
import Testing

@testable import StanokKit

struct GitTreeCoverageTests {

    @Test
    func everyChangeReachesTheTree() throws {
        let root = try Self.repository()
        defer { try? FileManager.default.removeItem(at: root) }

        let data = try Self.git(["status", "--porcelain=v2", "-z", "-uall"], at: root)
        let changes = GitStatusParser.parse(data)
        let snapshot = GitSnapshot(
            branch: "main",
            isDetached: false,
            root: root.path(percentEncoded: false),
            gitDirectory: root.appending(path: ".git").path(percentEncoded: false),
            added: 0,
            removed: 0,
            changes: changes
        )

        var seen: Set<String> = []
        for node in GitTreeBuilder.build(from: snapshot, at: root) {
            Self.collect(node, into: &seen)
        }

        #expect(!changes.isEmpty)
        #expect(Set(changes.map(\.path)).subtracting(seen).isEmpty)
    }
}

private extension GitTreeCoverageTests {

    static func collect(_ node: GitTreeNode, into paths: inout Set<String>) {
        paths.insert(node.relativePath)

        for child in node.children {
            collect(child, into: &paths)
        }
    }

    @discardableResult
    static func git(_ arguments: [String], at root: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = ["-C", root.path(percentEncoded: false)] + arguments
        process.environment = ["GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return data
    }

    static func write(_ text: String, to path: String, in root: URL) throws {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func repository() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try git(["init", "-b", "main"], at: root)
        try git(["config", "user.email", "test@example.com"], at: root)
        try git(["config", "user.name", "Test"], at: root)

        try write("one\n", to: "Sources/Core/One.swift", in: root)
        try write("two\n", to: "Sources/Deep/Nested/Two.swift", in: root)
        try write("three\n", to: "Docs/with space.md", in: root)
        try write("four\n", to: "Top.swift", in: root)

        try git(["add", "."], at: root)
        try git(["commit", "-m", "init"], at: root)

        try write("one changed\n", to: "Sources/Core/One.swift", in: root)
        try write("two changed\n", to: "Sources/Deep/Nested/Two.swift", in: root)
        try write("three changed\n", to: "Docs/with space.md", in: root)
        try write("new\n", to: "Sources/Fresh/New.swift", in: root)
        try git(["rm", "--quiet", "Top.swift"], at: root)

        return root
    }
}
