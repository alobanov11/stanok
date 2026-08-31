import Foundation

enum SessionMigration {

    enum FlattenError: Error, Equatable {

        case duplicateSessionID(UUID)
        case sessionCountMismatch(expected: Int, actual: Int)
    }

    static func flatten(_ legacyRepositories: [LegacyRepository]) throws -> [TerminalSession] {
        var sessions: [TerminalSession] = []
        var seenIDs: Set<UUID> = []

        for repository in legacyRepositories {
            for legacySession in repository.sessions {
                guard seenIDs.insert(legacySession.id).inserted else {
                    throw FlattenError.duplicateSessionID(legacySession.id)
                }

                sessions.append(
                    TerminalSession(
                        id: legacySession.id,
                        name: legacySession.name,
                        url: repository.url,
                        workspace: WorkspaceState(
                            selectedFile: repository.workspace.selectedFile,
                            panelMode: repository.workspace.panelMode,
                            expandedFolderPaths: repository.workspace.expandedFolderPaths,
                            scrollAnchorPath: repository.workspace.scrollAnchorPath
                        )
                    )
                )
            }
        }

        let expectedCount = legacyRepositories.reduce(0) { $0 + $1.sessions.count }
        guard sessions.count == expectedCount else {
            throw FlattenError.sessionCountMismatch(expected: expectedCount, actual: sessions.count)
        }

        return sessions
    }

    static func resolveSelectedSessionID(
        legacyRepositories: [LegacyRepository],
        sessions: [TerminalSession]
    ) -> TerminalSession.ID? {
        let mostRecentlyOpened = legacyRepositories.max { $0.lastOpenedAt < $1.lastOpenedAt }

        guard
            let candidate = mostRecentlyOpened?.workspace.lastSessionID,
            sessions.contains(where: { $0.id == candidate })
        else { return sessions.first?.id }

        return candidate
    }
}
