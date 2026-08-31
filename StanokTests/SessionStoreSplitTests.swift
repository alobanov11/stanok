import Foundation
import Testing

@testable import StanokKit

@MainActor
struct SessionStoreSplitTests {

    private static func makeStore() -> SessionStore {
        let name = "session-store-split-tests-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: name, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return SessionStore(
            file: directory.appending(path: "sessions.json"),
            legacyFile: directory.appending(path: "repositories.json")
        )
    }

    @Test
    func splittingAddsAPaneUnderTheRootAndKeepsItOutOfTheTopLevel() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)

        let pane = try #require(store.splitSession(root.id, direction: .trailing))

        #expect(pane.parentID == root.id)
        #expect(store.roots.map(\.id) == [root.id])
        #expect(try store.panes(of: #require(store.session(for: root.id))).map(\.id)
            == [root.id, pane.id]
        )
    }

    @Test
    func aNewPaneOpensInTheFolderOfThePaneItWasSplitFrom() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)

        let pane = try #require(store.splitSession(root.id, direction: .bottom))

        #expect(pane.url == root.url)
    }

    @Test
    func splittingAPaneNestsTheNewOneNextToIt() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)
        let first = try #require(store.splitSession(root.id, direction: .trailing))

        let second = try #require(store.splitSession(first.id, direction: .bottom))

        let updated = try #require(store.session(for: root.id))
        #expect(second.parentID == root.id)
        #expect(updated.layout == .split(
            .horizontal,
            [.leaf(root.id), .split(.vertical, [.leaf(first.id), .leaf(second.id)])]
        ))
    }

    @Test
    func closingTheLastPaneLeavesAPlainRootWithoutALayout() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)
        let pane = try #require(store.splitSession(root.id, direction: .trailing))

        store.removeSession(pane.id)

        let updated = try #require(store.session(for: root.id))
        #expect(updated.layout == nil)
        #expect(store.sessions.map(\.id) == [root.id])
    }

    @Test
    func closingTheRootPromotesAPaneAndKeepsTheRestOfTheGroup() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)
        let first = try #require(store.splitSession(root.id, direction: .trailing))
        let second = try #require(store.splitSession(first.id, direction: .bottom))

        store.removeSession(root.id)

        let heir = try #require(store.session(for: first.id))
        let survivor = try #require(store.session(for: second.id))
        #expect(store.roots.map(\.id) == [first.id])
        #expect(heir.parentID == nil)
        #expect(heir.layout == .split(.vertical, [.leaf(first.id), .leaf(second.id)]))
        #expect(survivor.parentID == first.id)
    }

    @Test
    func splitsSurviveARestartOfTheStore() throws {
        let name = "session-store-split-tests-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appending(path: "sessions.json")
        let legacyFile = directory.appending(path: "repositories.json")

        let store = SessionStore(file: file, legacyFile: legacyFile)
        let root = try #require(store.sessions.first)
        let pane = try #require(store.splitSession(root.id, direction: .bottom))
        store.flushPendingSave()

        let restored = SessionStore(file: file, legacyFile: legacyFile)
        let restoredRoot = try #require(restored.session(for: root.id))

        #expect(restored.roots.map(\.id) == [root.id])
        #expect(restored.session(for: pane.id)?.parentID == root.id)
        #expect(restoredRoot.layout == .split(.vertical, [.leaf(root.id), .leaf(pane.id)]))
        #expect(restored.panes(of: restoredRoot).map(\.id) == [root.id, pane.id])
    }

    @Test
    func splittingAPaneThatIsMissingFromTheLayoutIsRefused() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)
        let other = store.addSession(url: root.url)

        #expect(store.splitSession(other.id, direction: .trailing) != nil)
        #expect(store.splitSession(UUID(), direction: .trailing) == nil)
    }

    @Test
    func closingARootWithoutPanesRemovesItAlone() throws {
        let store = Self.makeStore()
        let root = try #require(store.sessions.first)
        let other = store.addSession(url: root.url)

        store.removeSession(root.id)

        #expect(store.sessions.map(\.id) == [other.id])
    }

    @Test
    func aPaneMissingFromItsRootLayoutIsPutBackOnLoad() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "session-store-split-tests-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let root = TerminalSession(name: "root", url: URL(filePath: "/tmp"))
        let pane = TerminalSession(name: "pane", url: URL(filePath: "/tmp"), parentID: root.id)
        let file = directory.appending(path: "sessions.json")
        try JSONEncoder()
            .encode(SessionFile(sessions: [root, pane], selectedSessionID: root.id))
            .write(to: file)

        let store = SessionStore(
            file: file,
            legacyFile: directory.appending(path: "repositories.json")
        )
        let restoredRoot = try #require(store.session(for: root.id))

        #expect(store.roots.map(\.id) == [root.id])
        #expect(restoredRoot.layout?.contains(pane.id) == true)
        #expect(store.panes(of: restoredRoot).map(\.id) == [root.id, pane.id])
    }

    @Test
    func aPaneWhoseTerminalIsGoneStandsOnItsOwn() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "session-store-split-tests-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let orphan = TerminalSession(name: "orphan", url: URL(filePath: "/tmp"), parentID: UUID())
        let file = directory.appending(path: "sessions.json")
        try JSONEncoder()
            .encode(SessionFile(sessions: [orphan], selectedSessionID: orphan.id))
            .write(to: file)

        let store = SessionStore(
            file: file,
            legacyFile: directory.appending(path: "repositories.json")
        )

        #expect(store.roots.map(\.id) == [orphan.id])
        #expect(store.session(for: orphan.id)?.parentID == nil)
    }
}
