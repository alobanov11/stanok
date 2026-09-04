import Foundation
import Testing

@testable import StanokKit

@MainActor
struct WorkspaceShowTests {

    private static func store() -> SessionStore {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        return SessionStore(
            file: directory.appending(path: "sessions.json"),
            legacyFile: directory.appending(path: "repositories.json")
        )
    }

    @Test
    func aTerminalTakesAFreeColumnUntilTheAreaIsFull() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))
        let third = store.addSession(url: URL(filePath: "/tmp"))

        store.show(first.id, capacity: 2, replacing: nil)
        store.show(second.id, capacity: 2, replacing: first.id)

        #expect(store.visible == [first.id, second.id])

        store.show(third.id, capacity: 2, replacing: second.id)

        #expect(store.visible == [first.id, third.id])
    }

    @Test
    func aFullAreaReplacesThePreviouslyActiveTerminal() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))
        let third = store.addSession(url: URL(filePath: "/tmp"))

        store.show(first.id, capacity: 2, replacing: nil)
        store.show(second.id, capacity: 2, replacing: first.id)
        store.show(third.id, capacity: 2, replacing: second.id)

        #expect(store.visible == [first.id, third.id])
    }

    @Test
    func aNarrowWindowHidesTerminalsTemporarily() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))

        store.show(first.id, capacity: 2, replacing: nil)
        store.show(second.id, capacity: 2, replacing: nil)
        store.limit(to: 1, keeping: second.id)

        #expect(store.visible == [second.id])
        #expect(store.shown == [first.id, second.id])

        store.limit(to: 2, keeping: second.id)

        #expect(store.visible == [first.id, second.id])
    }

    @Test
    func openingACrowdedTerminalKeepsTheAreaWithinCapacity() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))

        store.show(first.id, capacity: 2, replacing: nil)
        store.show(second.id, capacity: 2, replacing: nil)
        store.limit(to: 1, keeping: second.id)
        store.show(first.id, capacity: 1, replacing: second.id)

        #expect(store.visible == [first.id])
    }

    @Test
    func hidingTheLastVisibleTerminalBringsBackACrowdedOne() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))

        store.show(first.id, capacity: 2, replacing: nil)
        store.show(second.id, capacity: 2, replacing: nil)
        store.limit(to: 1, keeping: second.id)
        store.hide(second.id, capacity: 1)

        #expect(store.visible == [first.id])
    }

    @Test
    func draggingSwapsTerminalsInBothDirections() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))
        let third = store.addSession(url: URL(filePath: "/tmp"))

        store.move(third.id, before: first.id)

        #expect(store.sessions.map(\.id).suffix(3) == [third.id, second.id, first.id])
    }

    @Test
    func columnsKeepTheirMinimumWidthWithGaps() throws {
        let fits = WorkspaceGeometry.fit(
            room: 1440,
            minimum: WorkspaceLayout.minimumTerminalWidth
        )

        #expect(fits == 1)
    }

    @Test
    func aHiddenTerminalReturnsToItsOriginalPlaceInTheRow() throws {
        let store = Self.store()
        let first = store.addSession(url: URL(filePath: "/tmp"))
        let second = store.addSession(url: URL(filePath: "/tmp"))

        store.show(first.id, capacity: 2, replacing: nil)
        store.show(second.id, capacity: 2, replacing: nil)
        store.hide(first.id, capacity: 2)
        store.show(first.id, capacity: 2, replacing: nil)

        let order = store.sessions.filter { store.visible.contains($0.id) }.map(\.id)

        #expect(order == [first.id, second.id])
    }
}
