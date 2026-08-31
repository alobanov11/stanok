import Foundation
import Testing

import StanokKit

@MainActor
struct ShellProcessLabelStoreTests {

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "shell-process-label-store-tests-\(UUID().uuidString)")
    }

    @Test
    func missingLabelFileReportsNoPID() {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ShellProcessLabelStore(directory: directory)

        #expect(store.pid(forLabel: "missing") == nil)
    }

    @Test
    func aPlainPIDIsParsedWithSurroundingWhitespaceTrimmed() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write("  4242 \n", label: "tab-1", in: directory)
        let store = ShellProcessLabelStore(directory: directory)

        #expect(store.pid(forLabel: "tab-1") == 4242)
    }

    @Test
    func garbageContentsAreRejectedRatherThanPartiallyParsed() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ShellProcessLabelStore(directory: directory)
        let cases = ["", "   ", "abc", "12abc", "-5", "0", "123\n456", "99999999999999"]

        for (index, contents) in cases.enumerated() {
            let label = "garbage-\(index)"
            try write(contents, label: label, in: directory)

            let message = "expected nil for \(contents.debugDescription)"
            #expect(store.pid(forLabel: label) == nil, "\(message)")
        }
    }

    @Test
    func removingALabelDeletesItsFile() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write("100\n", label: "tab-1", in: directory)
        let store = ShellProcessLabelStore(directory: directory)

        store.removeLabel("tab-1")

        #expect(store.pid(forLabel: "tab-1") == nil)
    }

    @Test
    func purgingStaleLabelsRemovesEveryFileInTheDirectory() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try write("100\n", label: "tab-1", in: directory)
        try write("200\n", label: "tab-2", in: directory)
        let store = ShellProcessLabelStore(directory: directory)

        store.purgeStaleLabels()

        #expect(store.pid(forLabel: "tab-1") == nil)
        #expect(store.pid(forLabel: "tab-2") == nil)
    }

    private func write(_ contents: String, label: String, in directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try contents.write(
            to: directory.appending(path: label, directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
    }
}
