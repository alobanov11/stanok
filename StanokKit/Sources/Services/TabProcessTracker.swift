import Foundation

@MainActor
@Observable
public final class TabProcessTracker {

    private enum PollBudget {

        static let attempts = 20
        static let interval = Duration.milliseconds(100)
    }

    public var usage: [TerminalSession.ID: ProcessTreeUsage] {
        trackedPIDs.reduce(into: [:]) { result, entry in
            result[entry.key] = monitor.usage[entry.value]
        }
    }

    private let monitor: ProcessTreeMonitor
    private let labels: ShellProcessLabelStore

    private var trackedPIDs: [TerminalSession.ID: Int32] = [:]

    @ObservationIgnored
    private var pollTasks: [TerminalSession.ID: Task<Void, Never>] = [:]

    public init(
        monitor: ProcessTreeMonitor = ProcessTreeMonitor(),
        labels: ShellProcessLabelStore = ShellProcessLabelStore()
    ) {
        self.monitor = monitor
        self.labels = labels

        // Почему: обход pid-файлов на старте отдавал микрофриз ещё до первого кадра
        Task { @MainActor [labels] in
            await Task.yield()
            labels.purgeStaleLabels()
        }
    }

    public func beginTracking(_ sessionID: TerminalSession.ID) {
        guard trackedPIDs[sessionID] == nil, pollTasks[sessionID] == nil else { return }

        let label = sessionID.uuidString
        pollTasks[sessionID] = Task { [weak self] in
            await self?.pollForPID(sessionID: sessionID, label: label)
        }
    }

    public func endTracking(_ sessionID: TerminalSession.ID) {
        pollTasks[sessionID]?.cancel()
        pollTasks[sessionID] = nil

        if let pid = trackedPIDs.removeValue(forKey: sessionID) {
            monitor.stopObserving(pid)
        }

        labels.removeLabel(sessionID.uuidString)
    }

    public func processNames(for sessionID: TerminalSession.ID) -> Set<String> {
        guard let pid = trackedPIDs[sessionID] else { return [] }

        return monitor.processNames[pid] ?? []
    }

    private func pollForPID(sessionID: TerminalSession.ID, label: String) async {
        for _ in 0..<PollBudget.attempts {
            guard !Task.isCancelled else { return }

            if let pid = labels.pid(forLabel: label) {
                trackedPIDs[sessionID] = pid
                monitor.observe(pid)
                pollTasks[sessionID] = nil
                return
            }

            try? await Task.sleep(for: PollBudget.interval)
        }

        pollTasks[sessionID] = nil
    }
}
