import Foundation

public protocol AgentSessionProvider: Sendable {

    var id: String { get }

    @MainActor
    func startWatching(onChange: @escaping @Sendable () -> Void)

    func loadSessions(for projectURL: URL) async -> AgentSessionsLoadState
}
