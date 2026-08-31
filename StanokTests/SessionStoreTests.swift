import Foundation
import Testing

import StanokKit

@MainActor
struct SessionStoreTests {

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

    private static func temporaryDirectory() -> URL {
        let name = "session-store-tests-\(UUID().uuidString)"
        let directory = FileManager.default.temporaryDirectory
            .appending(path: name, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test
    func migratingTheOwnerFixtureThroughTheStoreYieldsFourSessionsNotZero() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = directory.appending(path: "repositories.json")
        try Data(Fixture.ownerRepositoriesWithoutWorkspaceKey.utf8).write(to: legacyFile)

        let sessionsFile = directory.appending(path: "sessions.json")
        let store = SessionStore(file: sessionsFile, legacyFile: legacyFile)

        #expect(store.sessions.count == 4)
        #expect(
            Set(store.sessions.map(\.url.lastPathComponent))
                == ["wiki", "relix-ios", "tabby-app-ios", "tom"]
        )
    }

    @Test
    func migrationWritesSessionsFileOnFirstLaunchInTheSameCommit() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = directory.appending(path: "repositories.json")
        try Data(Fixture.ownerRepositoriesWithoutWorkspaceKey.utf8).write(to: legacyFile)

        let sessionsFile = directory.appending(path: "sessions.json")
        #expect(!FileManager.default.fileExists(atPath: sessionsFile.path(percentEncoded: false)))

        _ = SessionStore(file: sessionsFile, legacyFile: legacyFile)

        #expect(FileManager.default.fileExists(atPath: sessionsFile.path(percentEncoded: false)))

        let onDisk = try JSONDecoder().decode(
            SessionFile.self,
            from: Data(contentsOf: sessionsFile)
        )
        #expect(onDisk.sessions.count == 4)
    }

    @Test
    func migrationNeverMutatesTheLegacyFile() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = directory.appending(path: "repositories.json")
        let legacyBytes = Data(Fixture.ownerRepositoriesWithoutWorkspaceKey.utf8)
        try legacyBytes.write(to: legacyFile)

        let sessionsFile = directory.appending(path: "sessions.json")
        _ = SessionStore(file: sessionsFile, legacyFile: legacyFile)

        let legacyBytesAfter = try Data(contentsOf: legacyFile)
        #expect(legacyBytesAfter == legacyBytes)
    }

    @Test
    func aSessionsFileOnDiskIsUsedInsteadOfMigratingAgain() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyFile = directory.appending(path: "repositories.json")
        try Data(Fixture.ownerRepositoriesWithoutWorkspaceKey.utf8).write(to: legacyFile)

        let sessionID = UUID()
        let existing = SessionFile(
            sessions: [
                TerminalSession(id: sessionID, name: "solo shell", url: URL(filePath: "/tmp"))
            ],
            selectedSessionID: sessionID
        )
        let sessionsFile = directory.appending(path: "sessions.json")
        try JSONEncoder().encode(existing).write(to: sessionsFile)

        let store = SessionStore(file: sessionsFile, legacyFile: legacyFile)

        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.name == "solo shell")
        #expect(store.selectedSessionID == sessionID)
    }

    @Test
    func updateWorkspaceDebouncesTheDiskWriteUntilFlush() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sessionsFile = directory.appending(path: "sessions.json")
        let store = SessionStore(
            file: sessionsFile,
            legacyFile: directory.appending(path: "repositories.json")
        )
        let sessionID = try #require(store.sessions.first?.id)

        store.updateWorkspace(sessionID) { $0.selectedFile = "README.md" }

        let beforeFlush = try JSONDecoder().decode(
            SessionFile.self,
            from: Data(contentsOf: sessionsFile)
        )
        #expect(beforeFlush.sessions.first?.workspace.selectedFile == nil)
        #expect(store.sessions.first?.workspace.selectedFile == "README.md")

        store.flushPendingSave()

        let afterFlush = try JSONDecoder().decode(
            SessionFile.self,
            from: Data(contentsOf: sessionsFile)
        )
        #expect(afterFlush.sessions.first?.workspace.selectedFile == "README.md")
    }

    @Test
    func structuralChangesStillWriteImmediately() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sessionsFile = directory.appending(path: "sessions.json")
        let store = SessionStore(
            file: sessionsFile,
            legacyFile: directory.appending(path: "repositories.json")
        )

        store.addSession(url: URL(filePath: "/tmp"))

        let onDisk = try JSONDecoder().decode(
            SessionFile.self,
            from: Data(contentsOf: sessionsFile)
        )
        #expect(onDisk.sessions.count == 2)
    }

    @Test
    func setLiveTitleUpdatesTheSessionWithoutTouchingDisk() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sessionsFile = directory.appending(path: "sessions.json")
        let store = SessionStore(
            file: sessionsFile,
            legacyFile: directory.appending(path: "repositories.json")
        )
        let sessionID = try #require(store.sessions.first?.id)

        store.setLiveTitle("npm run dev", for: sessionID)

        let session = store.sessions.first
        #expect(session?.liveTitle == "npm run dev")
        #expect(session?.displayName == "npm run dev")

        let onDisk = try Data(contentsOf: sessionsFile)
        let json = try #require(String(data: onDisk, encoding: .utf8))
        #expect(!json.contains("liveTitle"))
        #expect(!json.contains("npm run dev"))
    }

    @Test
    func updateDirectoryDebouncesTheDiskWriteUntilFlush() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sessionsFile = directory.appending(path: "sessions.json")
        let store = SessionStore(
            file: sessionsFile,
            legacyFile: directory.appending(path: "repositories.json")
        )
        let sessionID = try #require(store.sessions.first?.id)
        let newURL = URL(filePath: "/tmp/moved")

        store.updateDirectory(sessionID, identity: newURL, reported: newURL)

        let beforeFlush = try JSONDecoder().decode(
            SessionFile.self,
            from: Data(contentsOf: sessionsFile)
        )
        #expect(beforeFlush.sessions.first?.url != newURL)
        #expect(store.sessions.first?.url == newURL)

        store.flushPendingSave()

        let afterFlush = try JSONDecoder().decode(
            SessionFile.self,
            from: Data(contentsOf: sessionsFile)
        )
        #expect(afterFlush.sessions.first?.url == newURL)
    }

    @Test
    func updateDirectoryNeverPersistsTheLiveDirectory() throws {
        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let sessionsFile = directory.appending(path: "sessions.json")
        let store = SessionStore(
            file: sessionsFile,
            legacyFile: directory.appending(path: "repositories.json")
        )
        let sessionID = try #require(store.sessions.first?.id)
        let identity = URL(filePath: "/private/tmp/identity-only")
        let reported = URL(filePath: "/tmp/reported-only")

        store.updateDirectory(sessionID, identity: identity, reported: reported)
        store.flushPendingSave()

        #expect(store.sessions.first?.url == identity)
        #expect(store.sessions.first?.liveDirectory == reported)

        let onDisk = try Data(contentsOf: sessionsFile)
        let json = try #require(String(data: onDisk, encoding: .utf8))
        #expect(!json.contains("liveDirectory"))
        #expect(!json.contains("reported-only"))
    }
}
