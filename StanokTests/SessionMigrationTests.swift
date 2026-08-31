import Foundation
import Testing

@testable import StanokKit

struct SessionMigrationTests {

    private enum Fixture {

        static let ownerRepositories = #"""

        [
          {
            "id" : "EDDA019C-FF50-40FC-9219-8E6286FE6D0A",
            "isExpanded" : true,
            "lastOpenedAt" : 809885134.555911,
            "openCount" : 138,
            "sessions" : [
              {
                "id" : "5E654FD1-450C-425D-B7B0-9790F44B7BA8",
                "isPinned" : false,
                "name" : "shell 2"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/tabby\/tabby-app-ios\/",
            "workspace" : {
              "lastSessionID" : "5E654FD1-450C-425D-B7B0-9790F44B7BA8",
              "panelMode" : "changes"
            }
          },
          {
            "id" : "D8ABF81A-C37B-442F-AF82-6529C9EEEF7F",
            "isExpanded" : false,
            "lastOpenedAt" : 809873433.97822,
            "openCount" : 62,
            "sessions" : [
              {
                "id" : "CAD281C8-F09A-44E8-960F-8F32C02A8F3D",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/wiki\/",
            "workspace" : {
              "lastSessionID" : "CAD281C8-F09A-44E8-960F-8F32C02A8F3D",
              "panelMode" : "changes",
              "selectedFile" : "software-smells\/bloaters.md"
            }
          },
          {
            "id" : "5598E043-E05E-4750-B1C5-7F3B10EA6D87",
            "isExpanded" : false,
            "lastOpenedAt" : 809813867.039599,
            "openCount" : 2,
            "sessions" : [
              {
                "id" : "AFCB0EC3-9FC9-48FB-A6E0-060BF55D1BD6",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/_archive\/_IOS_ARCHIVE_\/relix-ios\/",
            "workspace" : {
            }
          },
          {
            "id" : "2710CB76-AEEC-49CC-BC8B-219079F140C1",
            "isExpanded" : false,
            "lastOpenedAt" : 809808768.381355,
            "openCount" : 17,
            "sessions" : [
              {
                "id" : "080BE873-6664-4442-8A58-570535B0D8BC",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/",
            "workspace" : {
            }
          }
        ]

        """#

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
          }
        ]

        """#

        static let realOwnerRepositoriesSnapshot = #"""

        [
          {
            "id" : "EDDA019C-FF50-40FC-9219-8E6286FE6D0A",
            "isExpanded" : true,
            "lastOpenedAt" : 809886642.370177,
            "openCount" : 158,
            "sessions" : [
              {
                "id" : "5E654FD1-450C-425D-B7B0-9790F44B7BA8",
                "isPinned" : false,
                "name" : "shell 2"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/tabby\/tabby-app-ios\/",
            "workspace" : {
              "lastSessionID" : "5E654FD1-450C-425D-B7B0-9790F44B7BA8",
              "panelMode" : "branches"
            }
          },
          {
            "id" : "D8ABF81A-C37B-442F-AF82-6529C9EEEF7F",
            "isExpanded" : false,
            "lastOpenedAt" : 809873433.97822,
            "openCount" : 62,
            "sessions" : [
              {
                "id" : "CAD281C8-F09A-44E8-960F-8F32C02A8F3D",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/wiki\/",
            "workspace" : {
              "lastSessionID" : "CAD281C8-F09A-44E8-960F-8F32C02A8F3D",
              "panelMode" : "changes",
              "selectedFile" : "software-smells\/bloaters.md"
            }
          },
          {
            "id" : "5598E043-E05E-4750-B1C5-7F3B10EA6D87",
            "isExpanded" : false,
            "lastOpenedAt" : 809813867.039599,
            "openCount" : 2,
            "sessions" : [
              {
                "id" : "AFCB0EC3-9FC9-48FB-A6E0-060BF55D1BD6",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/Projects\/_archive\/_IOS_ARCHIVE_\/relix-ios\/",
            "workspace" : {
            }
          },
          {
            "id" : "2710CB76-AEEC-49CC-BC8B-219079F140C1",
            "isExpanded" : false,
            "lastOpenedAt" : 809808768.381355,
            "openCount" : 17,
            "sessions" : [
              {
                "id" : "080BE873-6664-4442-8A58-570535B0D8BC",
                "isPinned" : false,
                "name" : "shell"
              }
            ],
            "url" : "file:\/\/\/Users\/tom\/",
            "workspace" : {
            }
          }
        ]

        """#
    }

    private static func decodeLegacyRepositories(_ json: String) throws -> [LegacyRepository] {
        try JSONDecoder().decode([LegacyRepository].self, from: Data(json.utf8))
    }

    private static func legacyRepository(
        id: UUID = UUID(),
        url: URL,
        sessions: [LegacySession] = [],
        lastOpenedAt: Date = .distantPast,
        lastSessionID: UUID? = nil
    ) -> LegacyRepository {
        LegacyRepository(
            id: id,
            url: url,
            sessions: sessions,
            lastOpenedAt: lastOpenedAt,
            workspace: LegacyWorkspaceState(lastSessionID: lastSessionID)
        )
    }

    @Test
    func decodingToleratesARepositoryMissingTheNewlyAddedWorkspaceKey() throws {
        let repositories = try Self.decodeLegacyRepositories(
            Fixture.ownerRepositoriesWithoutWorkspaceKey
        )

        #expect(repositories.count == 1)
        #expect(repositories.first?.workspace.lastSessionID == nil)
        #expect(repositories.first?.workspace.selectedFile == nil)
    }

    @Test
    func decodingCorruptJSONThrowsInsteadOfProducingAnEmptyResult() {
        #expect(throws: (any Error).self) {
            _ = try Self.decodeLegacyRepositories("not json")
        }
    }

    @Test
    func decodingATruncatedFileThrowsInsteadOfProducingAnEmptyResult() {
        let truncated = String(Fixture.ownerRepositories.prefix(40))

        #expect(throws: (any Error).self) {
            _ = try Self.decodeLegacyRepositories(truncated)
        }
    }

    @Test
    func flattenPreservesEveryLegacySessionIDNameAndURL() throws {
        let repositories = try Self.decodeLegacyRepositories(Fixture.ownerRepositories)
        let sessions = try SessionMigration.flatten(repositories)

        #expect(sessions.count == 4)

        for repository in repositories {
            for legacySession in repository.sessions {
                let migrated = try #require(sessions.first { $0.id == legacySession.id })
                #expect(migrated.name == legacySession.name)
                #expect(migrated.url == repository.url)
            }
        }
    }

    @Test
    func flattenOfARepositoryWithZeroSessionsContributesNothing() throws {
        let repositories = [
            Self.legacyRepository(url: URL(filePath: "/tmp/empty"), sessions: [])
        ]

        let sessions = try SessionMigration.flatten(repositories)

        #expect(sessions.isEmpty)
    }

    @Test
    func flattenThrowsOnDuplicateSessionIDsAcrossRepositories() {
        let sharedID = UUID()
        let repositories = [
            Self.legacyRepository(
                url: URL(filePath: "/tmp/one"),
                sessions: [LegacySession(id: sharedID, name: "shell")]
            ),
            Self.legacyRepository(
                url: URL(filePath: "/tmp/two"),
                sessions: [LegacySession(id: sharedID, name: "shell")]
            )
        ]

        #expect(throws: SessionMigration.FlattenError.duplicateSessionID(sharedID)) {
            _ = try SessionMigration.flatten(repositories)
        }
    }

    @Test
    func flattenSucceedsForAnUnmountedURL() throws {
        let unmounted = URL(filePath: "/Volumes/DoesNotExist/gone")
        let repositories = [
            Self.legacyRepository(
                url: unmounted,
                sessions: [LegacySession(id: UUID(), name: "shell")]
            )
        ]

        let sessions = try SessionMigration.flatten(repositories)

        #expect(sessions.count == 1)
        #expect(sessions.first?.url == unmounted)
        #expect(sessions.first?.isReachable == false)
    }

    @Test
    func resolveSelectedSessionIDPicksTheMostRecentlyOpenedRepositorysTab() throws {
        let repositories = try Self.decodeLegacyRepositories(Fixture.ownerRepositories)
        let sessions = try SessionMigration.flatten(repositories)

        let selected = SessionMigration.resolveSelectedSessionID(
            legacyRepositories: repositories,
            sessions: sessions
        )

        #expect(selected == UUID(uuidString: "5E654FD1-450C-425D-B7B0-9790F44B7BA8"))
    }

    @Test
    func resolveSelectedSessionIDFallsBackToTheFirstShellWhenNothingMatches() {
        let dangling = UUID()
        let repositories = [
            Self.legacyRepository(
                url: URL(filePath: "/tmp/one"),
                lastOpenedAt: .now,
                lastSessionID: dangling
            )
        ]
        let firstSession = TerminalSession(name: "shell", url: URL(filePath: "/tmp/one"))
        let sessions = [firstSession]

        let selected = SessionMigration.resolveSelectedSessionID(
            legacyRepositories: repositories,
            sessions: sessions
        )

        #expect(selected == firstSession.id)
    }

    @Test
    func flatteningTheRealRepositoriesFileYieldsFourShellsWithTheirURLsAndNames() throws {
        let repositories = try Self.decodeLegacyRepositories(Fixture.realOwnerRepositoriesSnapshot)
        let sessions = try SessionMigration.flatten(repositories)

        #expect(sessions.count == 4)
        #expect(
            Set(sessions.map(\.url.lastPathComponent))
                == ["wiki", "relix-ios", "tabby-app-ios", "tom"]
        )
        #expect(
            Set(sessions.map(\.name))
                == ["shell", "shell 2"]
        )
    }
}
