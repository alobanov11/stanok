import Foundation
import Testing

import StanokKit

@MainActor
struct RepositoryStoreTests {

    private enum Fixture {

        static let ownerRepositoriesWithoutWorkspaceKey = #"""
        [
          {
            "id" : "D8ABF81A-C37B-442F-AF82-6529C9EEEF7F",
            "isExpanded" : true,
            "lastOpenedAt" : 809816842.768836,
            "openCount" : 2,
            "sessions" : [
              {
                "id" : "CAD281C8-F09A-44E8-960F-8F32C02A8F3D",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/wiki\/"
          },
          {
            "id" : "5598E043-E05E-4750-B1C5-7F3B10EA6D87",
            "isExpanded" : true,
            "lastOpenedAt" : 809813867.039599,
            "openCount" : 2,
            "sessions" : [
              {
                "id" : "AFCB0EC3-9FC9-48FB-A6E0-060BF55D1BD6",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/_archive\/_IOS_ARCHIVE_\/relix-ios\/"
          },
          {
            "id" : "EDDA019C-FF50-40FC-9219-8E6286FE6D0A",
            "isExpanded" : true,
            "lastOpenedAt" : 809808769.372414,
            "openCount" : 16,
            "sessions" : [
              {
                "id" : "F8516275-8219-4BA6-84FD-F84E0130F2ED",
                "isPinned" : false,
                "name" : "shell 1"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/tabby\/tabby-app-ios\/"
          },
          {
            "id" : "2710CB76-AEEC-49CC-BC8B-219079F140C1",
            "isExpanded" : true,
            "lastOpenedAt" : 809808768.381355,
            "openCount" : 17,
            "sessions" : [
              {
                "id" : "080BE873-6664-4442-8A58-570535B0D8BC",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/"
          }
        ]
        """#
    }

    private static func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "repository-store-tests-\(UUID().uuidString).json")
    }

    @Test
    func decodesOwnerFixtureMissingWorkspaceKeyIntoFourProjects() throws {
        let repositories = try JSONDecoder().decode(
            [Repository].self,
            from: Data(Fixture.ownerRepositoriesWithoutWorkspaceKey.utf8)
        )

        #expect(repositories.count == 4)
        #expect(
            Set(repositories.map(\.name))
                == ["wiki", "relix-ios", "tabby-app-ios", "tom"]
        )
        #expect(repositories.allSatisfy { $0.workspace == WorkspaceState() })
    }

    @Test
    func loadingOwnerFixtureThroughTheStoreYieldsFourProjectsNotZero() throws {
        let file = Self.temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }

        try Data(Fixture.ownerRepositoriesWithoutWorkspaceKey.utf8).write(to: file)

        let store = RepositoryStore(file: file)

        #expect(store.repositories.count == 4)
        #expect(
            Set(store.repositories.map(\.name))
                == ["wiki", "relix-ios", "tabby-app-ios", "tom"]
        )
    }

    @Test
    func corruptFileIsQuarantinedInsteadOfSilentlyOverwritten() throws {
        let file = Self.temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }

        try Data("not json".utf8).write(to: file)

        let store = RepositoryStore(file: file)

        #expect(store.repositories.count == 1)

        let directory = file.deletingLastPathComponent()
        let siblings = try FileManager.default.contentsOfDirectory(atPath: directory.path())
        let quarantined = siblings.filter {
            $0.hasPrefix(file.lastPathComponent) && $0 != file.lastPathComponent
        }

        #expect(quarantined.count == 1)

        if let name = quarantined.first {
            let backupURL = directory.appending(path: name)
            let backupData = try Data(contentsOf: backupURL)
            #expect(String(data: backupData, encoding: .utf8) == "not json")
            try? FileManager.default.removeItem(at: backupURL)
        }
    }

    @Test
    func updateWorkspaceDebouncesTheDiskWriteUntilFlush() throws {
        let file = Self.temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let store = RepositoryStore(file: file)
        let repositoryID = try #require(store.repositories.first?.id)

        store.updateWorkspace(repositoryID) { $0.selectedFile = "README.md" }

        let beforeFlush = try JSONDecoder().decode(
            [Repository].self,
            from: Data(contentsOf: file)
        )
        #expect(beforeFlush.first?.workspace.selectedFile == nil)
        #expect(store.repositories.first?.workspace.selectedFile == "README.md")

        store.flushPendingSave()

        let afterFlush = try JSONDecoder().decode(
            [Repository].self,
            from: Data(contentsOf: file)
        )
        #expect(afterFlush.first?.workspace.selectedFile == "README.md")
    }

    @Test
    func structuralChangesStillWriteImmediately() throws {
        let file = Self.temporaryFile()
        defer { try? FileManager.default.removeItem(at: file) }

        let store = RepositoryStore(file: file)
        let repositoryID = try #require(store.repositories.first?.id)

        store.addSession(to: repositoryID)

        let onDisk = try JSONDecoder().decode([Repository].self, from: Data(contentsOf: file))
        #expect(onDisk.first?.sessions.count == 2)
    }
}
