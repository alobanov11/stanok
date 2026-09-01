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

    private enum GlobalRefresh {

        static let debounce = Duration.seconds(5)
        static let maximumWait: TimeInterval = 20
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
    private var globalStates: [String: AgentSessionsLoadState] = [:]
    private var globalRevisions: [String: Int] = [:]
    private var globalInFlight: Set<String> = []
    private var globalPendingRefresh: Set<String> = []
    private var observedGlobalProviders: Set<String> = []
    private var visibilityObserver: (any NSObjectProtocol)?
    private var lastGlobalRefreshAt: [String: Date] = [:]
    private var globalRefreshTasks: [String: Task<Void, Never>] = [:]

    public nonisolated init() {}

    private static func settled(_ states: [AgentSessionsLoadState]) -> Bool {
        let stillLoading = states.contains { if case .loading = $0 { true } else { false } }
        let hasLoaded = states.contains { if case .loaded = $0 { true } else { false } }

        return !stillLoading || hasLoaded
    }

    private static func split(
        _ states: [AgentSessionsLoadState]
    ) -> (sessions: [AgentSession], failures: [String]) {
        var sessions: [AgentSession] = []
        var failures: [String] = []

        for state in states {
            switch state {
            case .loading: continue
            case let .loaded(items): sessions.append(contentsOf: items)
            case let .failed(reason): failures.append(reason)
            }
        }

        return (sessions, failures)
    }

    private static func merge(_ states: [AgentSessionsLoadState]) -> AgentSessionsLoadState {
        guard !states.isEmpty else { return .loading }
        guard settled(states) else { return .loading }

        let (sessions, failures) = split(states)
        guard !sessions.isEmpty || failures.isEmpty else {
            return .failed(failures.joined(separator: "; "))
        }

        return .loaded(sessions.sorted { $0.lastActivityAt > $1.lastActivityAt })
    }

    public func register(_ provider: AgentSessionProvider) {
        guard providers[provider.id] == nil else { return }

        let providerID = provider.id
        providers[providerID] = provider
        observeVisibility()

        provider.startWatching { [weak self] in
            Task { @MainActor in
                self?.refreshAllObserved(providerID: providerID)
                self?.scheduleGlobalRefresh(providerID: providerID)
            }
        }
    }

    public func refreshEverything() {
        for providerID in providers.keys {
            refreshAllObserved(providerID: providerID)
            scheduleGlobalRefresh(providerID: providerID)
        }
    }

    public func sessions(for projectURL: URL) -> AgentSessionsLoadState {
        snapshots[projectURL] ?? .loading
    }

    public func sessions(for projectURL: URL, providerID: String) -> AgentSessionsLoadState {
        perProviderState[TrackingKey(providerID: providerID, projectURL: projectURL)] ?? .loading
    }

    public func allSessions(providerID: String) -> AgentSessionsLoadState {
        globalStates[providerID] ?? .loading
    }

    // Почему: версия дешевле, чем хеш пяти тысяч чатов на каждый пересчёт списка
    public func revision(providerID: String) -> Int {
        globalRevisions[providerID] ?? 0
    }

    public func observe(_ projectURL: URL) {
        guard observedProjects.insert(projectURL).inserted else { return }

        refreshAll(projectURL)
    }

    public func observeAllSessions(providerID: String) {
        guard observedGlobalProviders.insert(providerID).inserted else { return }

        refreshGlobal(providerID: providerID)
    }

    private func observeVisibility() {
        guard visibilityObserver == nil else { return }

        visibilityObserver = NotificationCenter.default.addObserver(
            forName: AgentSessionsVisibility.changed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshEverything() }
        }
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

    private func scheduleGlobalRefresh(providerID: String) {
        guard observedGlobalProviders.contains(providerID) else { return }

        let waited = lastGlobalRefreshAt[providerID].map { Date().timeIntervalSince($0) }
        if let waited, waited >= GlobalRefresh.maximumWait {
            refreshGlobal(providerID: providerID)
            return
        }

        globalRefreshTasks[providerID]?.cancel()
        globalRefreshTasks[providerID] = Task { [weak self] in
            try? await Task.sleep(for: GlobalRefresh.debounce)
            guard !Task.isCancelled else { return }

            self?.refreshGlobal(providerID: providerID)
        }
    }

    private func refreshGlobal(providerID: String) {
        globalRefreshTasks[providerID]?.cancel()
        globalRefreshTasks[providerID] = nil
        lastGlobalRefreshAt[providerID] = Date()
        guard let provider = providers[providerID] else { return }

        guard !globalInFlight.contains(providerID) else {
            globalPendingRefresh.insert(providerID)
            return
        }

        globalInFlight.insert(providerID)

        Task { [weak self] in
            await self?.runGlobalRefreshLoop(provider: provider, providerID: providerID)
        }
    }

    private func runGlobalRefreshLoop(provider: AgentSessionProvider, providerID: String) async {
        repeat {
            globalPendingRefresh.remove(providerID)
            let result = await provider.loadAllSessions()
            if globalStates[providerID] != result {
                globalStates[providerID] = result
                globalRevisions[providerID, default: 0] += 1
            }
        } while globalPendingRefresh.contains(providerID)

        globalInFlight.remove(providerID)
    }
}
