import Foundation

import StanokKit

actor CoalescingProvider: AgentSessionProvider {

    nonisolated let id = "coalescing-fake"

    nonisolated let relay = ChangeRelay()

    private(set) var callCount = 0

    private var continuation: CheckedContinuation<Void, Never>?

    private var results: [AgentSessionsLoadState] = []

    func push(_ result: AgentSessionsLoadState) {
        results.append(result)
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func startWatching(onChange: @escaping @Sendable () -> Void) {
        relay.store(onChange)
    }

    func loadSessions(for projectURL: URL) async -> AgentSessionsLoadState {
        callCount += 1
        await withCheckedContinuation { continuation = $0 }

        return results.isEmpty ? .loaded([]) : results.removeFirst()
    }
}
