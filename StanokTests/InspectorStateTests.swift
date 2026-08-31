import Foundation
import Testing

@testable import StanokKit

@MainActor
struct InspectorStateTests {

    @Test
    func twoTerminalsInTheSameFolderShareOneFileTree() {
        let state = InspectorState()
        let folder = URL(filePath: "/tmp/project")

        let first = state.fileTree(for: folder)
        let second = state.fileTree(for: URL(filePath: "/tmp/project/"))

        #expect(first === second)
    }

    @Test
    func differentFoldersKeepTheirOwnFileTrees() {
        let state = InspectorState()

        let first = state.fileTree(for: URL(filePath: "/tmp/one"))
        let second = state.fileTree(for: URL(filePath: "/tmp/two"))

        #expect(first !== second)
    }

    @Test
    func gitTreesAreSharedByRepositoryRootNotByFolder() {
        let state = InspectorState()

        #expect(state.changeTree(for: "/tmp/repo") === state.changeTree(for: "/tmp/repo"))
        #expect(state.branchTree(for: "/tmp/repo") === state.branchTree(for: "/tmp/repo"))
        #expect(state.changeTree(for: "/tmp/repo") !== state.changeTree(for: "/tmp/other"))
    }

    @Test
    func selectionIsRememberedPerFolder() {
        let state = InspectorState()
        let folder = URL(filePath: "/tmp/project")
        let file = URL(filePath: "/tmp/project/README.md")

        state.select(file, in: folder)

        #expect(state.selectedFile(in: folder) == file)
        #expect(state.selectedFile(in: URL(filePath: "/tmp/other")) == nil)
    }

    @Test
    func pruningDropsStateOfFoldersThatNoTerminalUsesAnyMore() {
        let state = InspectorState()
        let kept = URL(filePath: "/tmp/kept")
        let dropped = URL(filePath: "/tmp/dropped")
        let keptTree = state.fileTree(for: kept)
        state.select(dropped.appending(path: "file.swift"), in: dropped)
        _ = state.fileTree(for: dropped)
        _ = state.changeTree(for: "/tmp/dropped-repo")

        state.prune(folders: [URL(filePath: "/tmp/kept")], gitRoots: ["/tmp/kept"])

        #expect(state.fileTree(for: kept) === keptTree)
        #expect(state.selectedFile(in: dropped) == nil)
        #expect(state.changeTree(for: "/tmp/dropped-repo") !== state.changeTree(for: "/tmp/kept"))
    }
}
