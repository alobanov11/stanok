import Foundation
import Testing

import StanokKit

@MainActor
struct AgentSessionRegistryTests {

    @Test
    func aChangeSignalWhileARefreshIsInFlightIsCoalescedIntoOneExtraRefresh() async throws {
        let provider = CoalescingProvider()
        let staleResult = AgentSession(
            id: AgentSessionKey(providerID: "coalescing-fake", sessionID: "stale"),
            title: "Stale chat",
            lastActivityAt: .now,
            resumeAction: AgentResumeAction(executable: "claude", arguments: ["--resume", "stale"])
        )
        let freshResult = AgentSession(
            id: AgentSessionKey(providerID: "coalescing-fake", sessionID: "fresh"),
            title: "Fresh chat",
            lastActivityAt: .now,
            resumeAction: AgentResumeAction(executable: "claude", arguments: ["--resume", "fresh"])
        )
        await provider.push(.loaded([staleResult]))
        await provider.push(.loaded([freshResult]))

        let registry = AgentSessionRegistry()
        registry.register(provider)

        let projectURL = URL(fileURLWithPath: "/tmp/coalescing-project")
        registry.observe(projectURL)
        try await Task.sleep(for: .milliseconds(30))

        provider.relay.fire()
        try await Task.sleep(for: .milliseconds(30))

        await provider.release()
        try await Task.sleep(for: .milliseconds(30))
        await provider.release()
        try await Task.sleep(for: .milliseconds(30))

        let callCount = await provider.callCount
        #expect(callCount == 2)

        guard case let .loaded(sessions) = registry.sessions(for: projectURL) else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(sessions.map(\.title) == ["Fresh chat"])
    }
}
