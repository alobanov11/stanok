import Foundation
import Testing

@testable import StanokKit

@MainActor
struct SessionStoreOrderTests {

    private static func makeStore() -> SessionStore {
        let name = "session-store-order-tests-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: name, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return SessionStore(
            file: directory.appending(path: "sessions.json"),
            legacyFile: directory.appending(path: "repositories.json")
        )
    }

    @Test
    func movingATerminalDownReordersTheTopLevel() throws {
        let store = Self.makeStore()
        let first = try #require(store.sessions.first)
        let second = store.addSession(url: first.url)
        let third = store.addSession(url: first.url)

        store.moveRoot(first.id, to: 2)

        #expect(store.roots.map(\.id) == [second.id, third.id, first.id])
    }

    @Test
    func movingATerminalUpReordersTheTopLevel() throws {
        let store = Self.makeStore()
        let first = try #require(store.sessions.first)
        let second = store.addSession(url: first.url)

        store.moveRoot(second.id, to: 0)

        #expect(store.roots.map(\.id) == [second.id, first.id])
    }

    @Test
    func aMovedTerminalTakesItsPanesAlong() throws {
        let store = Self.makeStore()
        let first = try #require(store.sessions.first)
        let pane = try #require(store.splitSession(first.id, direction: .trailing))
        let second = store.addSession(url: first.url)

        store.moveRoot(first.id, to: 1)

        #expect(store.roots.map(\.id) == [second.id, first.id])
        #expect(store.sessions.map(\.id) == [second.id, first.id, pane.id])
        #expect(store.session(for: pane.id)?.parentID == first.id)
    }

    @Test
    func anOrderThatSurvivesARestartIsTheOneOnScreen() throws {
        let name = "session-store-order-tests-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appending(path: "sessions.json")
        let legacyFile = directory.appending(path: "repositories.json")
        let store = SessionStore(file: file, legacyFile: legacyFile)
        let first = try #require(store.sessions.first)
        let second = store.addSession(url: first.url)

        store.moveRoot(second.id, to: 0)
        store.flushPendingSave()

        let restored = SessionStore(file: file, legacyFile: legacyFile)

        #expect(restored.roots.map(\.id) == [second.id, first.id])
    }

    @Test
    func movingAPaneOrAnUnknownTerminalChangesNothing() throws {
        let store = Self.makeStore()
        let first = try #require(store.sessions.first)
        let pane = try #require(store.splitSession(first.id, direction: .bottom))
        let second = store.addSession(url: first.url)

        store.moveRoot(pane.id, to: 0)
        store.moveRoot(UUID(), to: 0)

        #expect(store.roots.map(\.id) == [first.id, second.id])
    }
}
