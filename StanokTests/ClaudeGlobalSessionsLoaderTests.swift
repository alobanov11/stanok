import Foundation
import Testing

import StanokKit

@testable import StanokAgents

struct ClaudeGlobalSessionsLoaderTests {

    private static func makeRoot() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    private static func makeProjectDirectory(root: URL, name: String) throws -> URL {
        let directory = root.appending(path: name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func write(_ line: String, to file: URL) throws {
        try Data((line + "\n").utf8).write(to: file)
    }

    private static func loaded(_ state: AgentSessionsLoadState) -> [AgentSession]? {
        guard case let .loaded(sessions) = state else { return nil }
        return sessions
    }

    @Test
    func uuidStemFileIsIncluded() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let directory = try Self.makeProjectDirectory(root: root, name: "some-project")
        let sessionID = UUID()
        let file = directory.appending(path: "\(sessionID.uuidString).jsonl")
        try Self.write(
            #"{"type":"ai-title","sessionId":"\#(sessionID.uuidString)","aiTitle":"Included"}"#,
            to: file
        )

        let state = await ClaudeGlobalSessionsLoader().load(root: root)
        let sessions = try #require(Self.loaded(state))

        #expect(sessions.map(\.title) == ["Included"])
        #expect(sessions.first?.id.sessionID == sessionID.uuidString)
    }

    @Test
    func journalStemFileIsRejected() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let directory = try Self.makeProjectDirectory(root: root, name: "some-project")
        let file = directory.appending(path: "journal.jsonl")
        try Self.write(
            #"{"type":"ai-title","sessionId":"whatever","aiTitle":"Dropped"}"#,
            to: file
        )

        let state = await ClaudeGlobalSessionsLoader().load(root: root)
        let sessions = try #require(Self.loaded(state))

        #expect(sessions.isEmpty)
    }

    @Test
    func nestedJournalFileIsRejected() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let sessionID = UUID()
        let directory = try Self.makeProjectDirectory(root: root, name: "some-project")
        let nested = directory
            .appending(path: sessionID.uuidString)
            .appending(path: "subagents")
            .appending(path: "workflows")
            .appending(path: "wf_1")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Self.write(
            #"{"type":"ai-title","sessionId":"\#(sessionID.uuidString)","aiTitle":"Dropped"}"#,
            to: nested.appending(path: "journal.jsonl")
        )

        let state = await ClaudeGlobalSessionsLoader().load(root: root)
        let sessions = try #require(Self.loaded(state))

        #expect(sessions.isEmpty)
    }

    @Test
    func filenameSessionIdMismatchIsRejected() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let directory = try Self.makeProjectDirectory(root: root, name: "some-project")
        let filenameID = UUID()
        let embeddedID = UUID()
        let file = directory.appending(path: "\(filenameID.uuidString).jsonl")
        try Self.write(
            #"{"type":"ai-title","sessionId":"\#(embeddedID.uuidString)","aiTitle":"Dropped"}"#,
            to: file
        )

        let state = await ClaudeGlobalSessionsLoader().load(root: root)
        let sessions = try #require(Self.loaded(state))

        #expect(sessions.isEmpty)
    }

    @Test
    func cwdIsCapturedAsFolder() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let directory = try Self.makeProjectDirectory(root: root, name: "some-project")
        let sessionID = UUID()
        let file = directory.appending(path: "\(sessionID.uuidString).jsonl")
        try Self.write(#"{"type":"attachment","cwd":"/tmp/my-folder"}"#, to: file)

        let state = await ClaudeGlobalSessionsLoader().load(root: root)
        let sessions = try #require(Self.loaded(state))

        #expect(sessions.first?.folder?.path(percentEncoded: false) == "/tmp/my-folder")
    }

    @Test
    func titleFallsBackToFirstUserMessageThenSessionID() async throws {
        let root = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let directory = try Self.makeProjectDirectory(root: root, name: "some-project")

        let withUserMessageID = UUID()
        try Self.write(
            #"{"type":"user","isSidechain":false,"message":{"role":"user","content":"Fix bug"}}"#,
            to: directory.appending(path: "\(withUserMessageID.uuidString).jsonl")
        )

        let withNeitherID = UUID()
        try Self.write(
            #"{"type":"attachment","sessionId":"\#(withNeitherID.uuidString)","cwd":"/tmp"}"#,
            to: directory.appending(path: "\(withNeitherID.uuidString).jsonl")
        )

        let state = await ClaudeGlobalSessionsLoader().load(root: root)
        let sessions = try #require(Self.loaded(state))
        let titles = Set(sessions.map(\.title))

        #expect(titles.contains("Fix bug"))
        #expect(titles.contains(withNeitherID.uuidString))
    }
}
