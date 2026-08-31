import Foundation

@MainActor
@Observable
public final class AgentSessionRegistry {

    public struct ProviderInfo: Identifiable, Sendable {

        public let id: String

        public let displayName: String
    }

    private struct TrackingKey: Hashable {

        let providerID: String

        let projectURL: URL
    }

    public var registeredProviders: [ProviderInfo] {
        providers.values
            .map { ProviderInfo(id: $0.id, displayName: $0.displayName) }
            .sorted { $0.id < $1.id }
    }

    private(set) var snapshots: [URL: AgentSessionsLoadState] = [:]

    private var providers: [String: AgentSessionProvider] = [:]

    private var perProviderState: [TrackingKey: AgentSessionsLoadState] = [:]

    private var inFlight: Set<TrackingKey> = []

    private var pendingRefresh: Set<TrackingKey> = []

    private var observedProjects: Set<URL> = []

    public nonisolated init() {}

    private static func merge(_ states: [AgentSessionsLoadState]) -> AgentSessionsLoadState {
        guard !states.isEmpty else { return .loading }

        let stillLoading = states.contains { if case .loading = $0 { true } else { false } }
        let hasLoaded = states.contains { if case .loaded = $0 { true } else { false } }
        guard !stillLoading || hasLoaded else { return .loading }

        var sessions: [AgentSession] = []
        var failures: [String] = []
        for state in states {
            switch state {
            case .loading: continue
            case let .loaded(items): sessions.append(contentsOf: items)
            case let .failed(reason): failures.append(reason)
            }
        }
        guard !sessions.isEmpty || failures.isEmpty else {
            return .failed(failures.joined(separator: "; "))
        }

        return .loaded(sessions.sorted { $0.lastActivityAt > $1.lastActivityAt })
    }

    public func register(_ provider: AgentSessionProvider) {
        guard providers[provider.id] == nil else { return }

        providers[provider.id] = provider
        provider.startWatching { [weak self] in
            Task { @MainActor in self?.refreshAllObserved(providerID: provider.id) }
        }
    }

    public func sessions(for projectURL: URL) -> AgentSessionsLoadState {
        snapshots[projectURL] ?? .loading
    }

    public func sessions(for projectURL: URL, providerID: String) -> AgentSessionsLoadState {
        perProviderState[TrackingKey(providerID: providerID, projectURL: projectURL)] ?? .loading
    }

    public func observe(_ projectURL: URL) {
        guard observedProjects.insert(projectURL).inserted else { return }

        refreshAll(projectURL)
    }

    private func refreshAllObserved(providerID: String) {
        for projectURL in observedProjects {
            refresh(providerID: providerID, projectURL: projectURL)
        }
    }

    private func refreshAll(_ projectURL: URL) {
        for providerID in providers.keys {
            refresh(providerID: providerID, projectURL: projectURL)
        }
    }

    private func refresh(providerID: String, projectURL: URL) {
        guard let provider = providers[providerID] else { return }

        let key = TrackingKey(providerID: providerID, projectURL: projectURL)
        guard !inFlight.contains(key) else {
            pendingRefresh.insert(key)
            return
        }

        inFlight.insert(key)

        Task { [weak self] in
            await self?.runRefreshLoop(provider: provider, key: key, projectURL: projectURL)
        }
    }

    private func runRefreshLoop(
        provider: AgentSessionProvider,
        key: TrackingKey,
        projectURL: URL
    ) async {
        repeat {
            pendingRefresh.remove(key)
            let result = await provider.loadSessions(for: projectURL)
            perProviderState[key] = result
            recomputeSnapshot(for: projectURL)
        } while pendingRefresh.contains(key)

        inFlight.remove(key)
    }

    private func recomputeSnapshot(for projectURL: URL) {
        let keys = providers.keys.map { TrackingKey(providerID: $0, projectURL: projectURL) }
        let states = keys.compactMap { perProviderState[$0] }
        snapshots[projectURL] = Self.merge(states)
    }

}
