import Foundation
import StanokKit

final class ClaudeGlobalSessionsLoader: Sendable {

    private let cache = ClaudeSessionFileCache()
    private let gate = ConcurrencyGate(limit: 8)

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

        let title = resolution.title ?? resolution.firstUserMessageText ?? id.uuidString
        let folder = resolution.cwd.map { URL(fileURLWithPath: $0) }

        let session = AgentSession(
            id: AgentSessionKey(
                providerID: ClaudeAgentProvider.providerID,
                sessionID: id.uuidString
            ),
            title: title,
            lastActivityAt: resolution.modifiedAt,
            resumeAction: AgentResumeAction(
                executable: "claude",
                arguments: ["--resume", id.uuidString],
                runningProcessName: "claude",
                inSessionText: "/resume \(id.uuidString)",
                workingDirectory: folder
            ),
            folder: folder
        )
        return session
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.path(percentEncoded: false),
            isDirectory: &isDirectory
        )
        return exists && isDirectory.boolValue
    }

    func load(root: URL) async -> AgentSessionsLoadState {
        let projectDirectories: [URL]
        do {
            projectDirectories = try FileManager.default
                .contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                .filter(Self.isDirectory)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .loaded([])
        } catch {
            Log.agents.error("failed to list the projects root")
            return .failed("Не удалось прочитать список проектов")
        }

        let visibleDirectories = AgentSessionsVisibility.includesServiceSessions
            ? projectDirectories
            : projectDirectories.filter {
                !ClaudeServiceSessionsFilter.isServiceDirectory($0.lastPathComponent)
            }

        var sessionFiles: [(url: URL, id: UUID)] = []
        for directory in visibleDirectories {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            for url in contents {
                guard url.pathExtension == "jsonl" else { continue }

                let stem = url.deletingPathExtension().lastPathComponent
                guard let id = UUID(uuidString: stem) else { continue }

                sessionFiles.append((url, id))
            }
        }

        let paths = Set(sessionFiles.map { $0.url.path(percentEncoded: false) })
        await cache.purge(keeping: paths)

        let cache = cache
        let gate = gate
        let results = await withTaskGroup(
            of: AgentSession?.self
        ) { group in
            for file in sessionFiles {
                group.addTask {
                    await gate.withPermit {
                        await Self.session(for: file.url, id: file.id, cache: cache)
                    }
                }
            }

            var collected: [AgentSession] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }

        return .loaded(results.sorted { $0.lastActivityAt > $1.lastActivityAt })
    }
}
