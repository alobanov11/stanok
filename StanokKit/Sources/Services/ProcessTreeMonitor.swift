import Foundation

@MainActor
@Observable
public final class ProcessTreeMonitor {

    public private(set) var usage: [Int32: ProcessTreeUsage] = [:]

    public private(set) var processNames: [Int32: Set<String>] = [:]

    private let reader: any ProcessTableReading

    private let interval: Duration

    private var observedRoots: Set<Int32> = []

    private var previousSnapshot: ProcessTableSnapshot?

    private var previousCapturedAt: Date?

    private var pollTask: Task<Void, Never>?

    public init(
        reader: any ProcessTableReading = DarwinProcessTableReader(),
        interval: Duration = .seconds(2)
    ) {
        self.reader = reader
        self.interval = interval
    }

    public func observe(_ pid: Int32) {
        guard observedRoots.insert(pid).inserted else { return }

        startIfNeeded()
    }

    public func stopObserving(_ pid: Int32) {
        guard observedRoots.remove(pid) != nil else { return }

        usage.removeValue(forKey: pid)
        processNames.removeValue(forKey: pid)
        guard observedRoots.isEmpty else { return }

        stop()
    }

    private func startIfNeeded() {
        guard pollTask == nil else { return }

        pollTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    private func stop() {
        pollTask?.cancel()
        pollTask = nil
        previousSnapshot = nil
        previousCapturedAt = nil
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: interval)
        }
    }

    private func tick() async {
        let roots = observedRoots
        guard !roots.isEmpty else { return }

        let now = Date()
        let current = await reader.snapshot()
        let elapsed = previousCapturedAt.map { now.timeIntervalSince($0) } ?? 0

        var next: [Int32: ProcessTreeUsage] = [:]
        var nextNames: [Int32: Set<String>] = [:]
        for root in roots {
            next[root] = ProcessTreeAggregator.usage(
                forSubtreeRoot: root,
                current: current,
                previous: previousSnapshot,
                elapsed: elapsed
            )
            nextNames[root] = ProcessTreeAggregator.subtreeProcessNames(ofRoot: root, in: current)
        }

        usage = next
        processNames = nextNames
        previousSnapshot = current
        previousCapturedAt = now
    }
}
