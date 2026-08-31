import Foundation
import StanokKit

public final class ClaudeAgentProvider: AgentSessionProvider, Sendable {

    public static let providerID = "claude"

    public static var defaultProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
            .appending(path: "projects", directoryHint: .isDirectory)
    }

    public var id: String { Self.providerID }
    public var displayName: String { "Claude" }
    private let projectsRoot: URL
    private let loader: ClaudeSessionsLoader
    private let globalLoader: ClaudeGlobalSessionsLoader
    private let watcher: ClaudeProjectsWatcher

    public init(projectsRoot: URL = ClaudeAgentProvider.defaultProjectsRoot) {
        self.projectsRoot = projectsRoot
        self.loader = ClaudeSessionsLoader()
        self.globalLoader = ClaudeGlobalSessionsLoader()
        self.watcher = ClaudeProjectsWatcher()
    }

    @MainActor
    public func startWatching(onChange: @escaping @Sendable () -> Void) {
        watcher.start(root: projectsRoot, onChange: onChange)
    }

    public func loadSessions(for projectURL: URL) async -> AgentSessionsLoadState {
        await loader.load(root: projectsRoot, projectURL: projectURL)
    }

    public func loadAllSessions() async -> AgentSessionsLoadState {
        await globalLoader.load(root: projectsRoot)
    }
}
