import Foundation
import StanokKit

final class ClaudeSessionsLoader: Sendable {

    private let cache = ClaudeSessionFileCache()

    private let gate = ConcurrencyGate(limit: 3)

    private static func session(
        for url: URL,
        id: UUID,
        cache: ClaudeSessionFileCache
    ) async -> AgentSession? {
        let path = url.path(percentEncoded: false)
        guard let resolution = await cache.resolve(path: path) else { return nil }

        let filenameID = id.uuidString.lowercased()
        if let sessionID = resolution.sessionID, sessionID.lowercased() != filenameID {
            return nil
        }

        let title = resolution.title ?? "Без названия"
        return AgentSession(
            id: AgentSessionKey(
                providerID: ClaudeAgentProvider.providerID,
                sessionID: id.uuidString
            ),
            title: title,
            lastActivityAt: resolution.modifiedAt,
            resumeAction: AgentResumeAction(
                executable: "claude",
                arguments: ["--resume", id.uuidString]
            )
        )
    }

    func load(root: URL, projectURL: URL) async -> AgentSessionsLoadState {
        guard
            let directory = ClaudeProjectDirectoryResolver.resolve(
                projectURL: projectURL,
                root: root
            )
        else {
            return .loaded([])
        }

        let sessionFiles: [(url: URL, id: UUID)]
        do {
            sessionFiles = try FileManager.default
                .contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                .compactMap { url in
                    guard url.pathExtension == "jsonl" else { return nil }

                    let stem = url.deletingPathExtension().lastPathComponent
                    guard let id = UUID(uuidString: stem) else { return nil }

                    return (url, id)
                }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .loaded([])
        } catch {
            Log.agents.error("failed to list a project's session directory")
            return .failed("Не удалось прочитать список сессий")
        }

        let paths = Set(sessionFiles.map { $0.url.path(percentEncoded: false) })
        await cache.purge(keeping: paths)

        let cache = cache
        let gate = gate
        let sessions = await withTaskGroup(of: AgentSession?.self) { group in
            for file in sessionFiles {
                group.addTask {
                    await gate.withPermit {
                        await Self.session(for: file.url, id: file.id, cache: cache)
                    }
                }
            }

            var results: [AgentSession] = []
            for await session in group {
                if let session { results.append(session) }
            }
            return results
        }

        return .loaded(sessions.sorted { $0.lastActivityAt > $1.lastActivityAt })
    }

}
