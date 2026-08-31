import Foundation
import Testing

import StanokKit

@testable import StanokAgents

struct ClaudeSessionsLoaderTests {

    private static func session(
        _ loader: ClaudeSessionsLoader,
        _ root: URL,
        _ projectURL: URL
    ) async throws -> AgentSession? {
        let state = await loader.load(root: root, projectURL: projectURL)
        guard case let .loaded(sessions) = state else {
            Issue.record("expected a loaded state")
            return nil
        }
        return sessions.first
    }

    private static func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    private static func projectURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/Users/test/\(name)")
    }

    private static func makeProjectDirectory(root: URL, projectURL: URL) throws -> URL {
        let rawPath = projectURL.path(percentEncoded: false)
        let encoded = rawPath.replacingOccurrences(of: "/", with: "-")
        let directory = root.appending(path: encoded)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func record(sessionID: UUID, title: String) -> String {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let id = sessionID.uuidString
        return #"{"type":"ai-title","sessionId":"\#(id)","aiTitle":"\#(escapedTitle)"}"#
    }

    private static func write(_ line: String, to file: URL) throws {
        try Data((line + "\n").utf8).write(to: file)
    }

    private static func append(_ line: String, to file: URL) throws {
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }

        try handle.seekToEnd()
        handle.write(Data((line + "\n").utf8))
    }

    @Test
    func missingProjectDirectoryYieldsEmptyLoaded() async {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let loader = ClaudeSessionsLoader()
        let state = await loader.load(root: root, projectURL: Self.projectURL("no-such-project"))

        guard case let .loaded(sessions) = state else {
            Issue.record("expected an empty loaded state")
            return
        }
        #expect(sessions.isEmpty)
    }

    @Test
    func appendedContentUpdatesTitle() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectURL = Self.projectURL("append-project")
        let directory = try Self.makeProjectDirectory(root: root, projectURL: projectURL)
        let sessionID = UUID()
        let file = directory.appending(path: "\(sessionID.uuidString).jsonl")

        try Self.write(Self.record(sessionID: sessionID, title: "First"), to: file)

        let loader = ClaudeSessionsLoader()
        let first = try await Self.session(loader, root, projectURL)
        #expect(first?.title == "First")

        try Self.append(Self.record(sessionID: sessionID, title: "Second"), to: file)

        let second = try await Self.session(loader, root, projectURL)
        #expect(second?.title == "Second")
    }

    @Test
    func truncationRereadsFromScratch() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectURL = Self.projectURL("truncate-project")
        let directory = try Self.makeProjectDirectory(root: root, projectURL: projectURL)
        let sessionID = UUID()
        let file = directory.appending(path: "\(sessionID.uuidString).jsonl")
        let padding = String(repeating: "y", count: 4096)

        let bigTitle = "Before truncation \(padding)"
        try Self.write(Self.record(sessionID: sessionID, title: bigTitle), to: file)

        let loader = ClaudeSessionsLoader()
        _ = try await Self.session(loader, root, projectURL)

        try Self.write(Self.record(sessionID: sessionID, title: "After truncation"), to: file)

        let after = try await Self.session(loader, root, projectURL)
        #expect(after?.title == "After truncation")
    }

    @Test
    func replacingFileAtSamePathResetsCache() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectURL = Self.projectURL("replace-project")
        let directory = try Self.makeProjectDirectory(root: root, projectURL: projectURL)
        let sessionID = UUID()
        let file = directory.appending(path: "\(sessionID.uuidString).jsonl")

        try Self.write(Self.record(sessionID: sessionID, title: "Original file"), to: file)

        let loader = ClaudeSessionsLoader()
        _ = try await Self.session(loader, root, projectURL)

        try FileManager.default.removeItem(at: file)
        try Self.write(Self.record(sessionID: sessionID, title: "Replacement file"), to: file)

        let after = try await Self.session(loader, root, projectURL)
        #expect(after?.title == "Replacement file")
    }

    @Test
    func filenameSessionIdMismatchIsDropped() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectURL = Self.projectURL("mismatch-project")
        let directory = try Self.makeProjectDirectory(root: root, projectURL: projectURL)
        let filenameID = UUID()
        let embeddedID = UUID()
        let file = directory.appending(path: "\(filenameID.uuidString).jsonl")

        try Self.write(Self.record(sessionID: embeddedID, title: "Should be dropped"), to: file)

        let loader = ClaudeSessionsLoader()
        let state = await loader.load(root: root, projectURL: projectURL)

        guard case let .loaded(sessions) = state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(sessions.isEmpty)
    }

    @Test
    func symlinkFilesAreRejected() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectURL = Self.projectURL("symlink-project")
        let directory = try Self.makeProjectDirectory(root: root, projectURL: projectURL)
        let realFile = root.appending(path: "outside.jsonl")
        let sessionID = UUID()

        let line = Self.record(sessionID: sessionID, title: "Outside the project")
        try Self.write(line, to: realFile)
        let symlink = directory.appending(path: "\(sessionID.uuidString).jsonl")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: realFile)

        let state = await ClaudeSessionsLoader().load(root: root, projectURL: projectURL)

        guard case let .loaded(sessions) = state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(sessions.isEmpty)
    }

    @Test
    func sessionsSortedByModificationDate() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let projectURL = Self.projectURL("sort-project")
        let directory = try Self.makeProjectDirectory(root: root, projectURL: projectURL)

        let olderID = UUID()
        let newerID = UUID()
        let olderFile = directory.appending(path: "\(olderID.uuidString).jsonl")
        let newerFile = directory.appending(path: "\(newerID.uuidString).jsonl")

        try Self.write(Self.record(sessionID: olderID, title: "Older"), to: olderFile)
        try Self.write(Self.record(sessionID: newerID, title: "Newer"), to: newerFile)

        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-600)],
            ofItemAtPath: olderFile.path(percentEncoded: false)
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: newerFile.path(percentEncoded: false)
        )

        let state = await ClaudeSessionsLoader().load(root: root, projectURL: projectURL)

        guard case let .loaded(sessions) = state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(sessions.map(\.title) == ["Newer", "Older"])
    }
}
