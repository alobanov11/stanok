import Foundation

@MainActor
@Observable
public final class ProcessTreeMonitor {

    public private(set) var usage: [Int32: ProcessTreeUsage] = [:]

    public private(set) var processNames: [Int32: Set<String>] = [:]

    private var observedRoots: Set<Int32> = []
    private var generation = 0
    private var previousSnapshot: ProcessTableSnapshot?
    private var previousCapturedAt: Date?
    private var pollTask: Task<Void, Never>?

    private let reader: any ProcessTableReading
    private let interval: Duration

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
}

private extension ProcessTreeMonitor {

    func startIfNeeded() {
        guard pollTask == nil else { return }

        generation += 1
        let started = generation
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, generation == started else { return }

                await tick(generation: started)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stop() {
        generation += 1
        pollTask?.cancel()
        pollTask = nil
        previousSnapshot = nil
        previousCapturedAt = nil
    }

    func tick(generation started: Int) async {
        let roots = observedRoots
        guard !roots.isEmpty else { return }

        let now = Date()
        let current = await reader.snapshot()
        guard generation == started, observedRoots == roots else { return }

        let elapsed = previousCapturedAt.map { now.timeIntervalSince($0) } ?? 0
        let previous = previousSnapshot

        // Почему: агрегация по каждому терминалу заново строила таблицу процессов на главном потоке
        let computed = await Task.detached(priority: .utility) {
            var usage: [Int32: ProcessTreeUsage] = [:]
            var names: [Int32: Set<String>] = [:]

            for root in roots {
                usage[root] = ProcessTreeAggregator.usage(
                    forSubtreeRoot: root,
                    current: current,
                    previous: previous,
                    elapsed: elapsed
                )
                names[root] = ProcessTreeAggregator.subtreeProcessNames(ofRoot: root, in: current)
            }

            return (usage, names)
        }.value

        guard generation == started, observedRoots == roots else { return }

        usage = computed.0
        processNames = computed.1
        previousSnapshot = current
        previousCapturedAt = now
    }
}
