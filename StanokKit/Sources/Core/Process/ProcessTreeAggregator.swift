import Foundation

public enum ProcessTreeAggregator {

    public static func subtreePIDs(
        ofRoot root: Int32,
        in snapshot: ProcessTableSnapshot
    ) -> Set<Int32> {
        guard snapshot.entries[root] != nil else { return [] }

        var childrenByParent: [Int32: [Int32]] = [:]
        for entry in snapshot.entries.values where entry.pid != entry.parentPID {
            childrenByParent[entry.parentPID, default: []].append(entry.pid)
        }

        var subtree: Set<Int32> = [root]
        var stack: [Int32] = [root]
        while let pid = stack.popLast() {
            for child in childrenByParent[pid] ?? [] where subtree.insert(child).inserted {
                stack.append(child)
            }
        }

        return subtree
    }

    static func childrenByParent(in snapshot: ProcessTableSnapshot) -> [Int32: [Int32]] {
        var children: [Int32: [Int32]] = [:]
        for entry in snapshot.entries.values where entry.pid != entry.parentPID {
            children[entry.parentPID, default: []].append(entry.pid)
        }

        return children
    }

    static func subtreePIDs(ofRoot root: Int32, children: [Int32: [Int32]]) -> Set<Int32> {
        var subtree: Set<Int32> = [root]
        var stack: [Int32] = [root]

        while let pid = stack.popLast() {
            for child in children[pid] ?? [] where subtree.insert(child).inserted {
                stack.append(child)
            }
        }

        return subtree
    }

    public static func subtreeProcessNames(
        ofRoot root: Int32,
        in snapshot: ProcessTableSnapshot
    ) -> Set<String> {
        Set(
            subtreePIDs(ofRoot: root, in: snapshot)
                .compactMap { snapshot.entries[$0]?.name }
                .filter { !$0.isEmpty }
        )
    }

    public static func totals(
        forSubtreeRoot root: Int32,
        in snapshot: ProcessTableSnapshot
    ) -> ProcessSubtreeTotals {
        var cpuTimeNanoseconds: UInt64 = 0
        var residentMemoryBytes: UInt64 = 0

        for pid in subtreePIDs(ofRoot: root, in: snapshot) {
            guard let entry = snapshot.entries[pid] else { continue }

            cpuTimeNanoseconds += entry.cpuTimeNanoseconds
            residentMemoryBytes += entry.residentMemoryBytes
        }

        return ProcessSubtreeTotals(
            cpuTimeNanoseconds: cpuTimeNanoseconds,
            residentMemoryBytes: residentMemoryBytes
        )
    }

    static func delta(
        for pid: Int32,
        current: ProcessTableSnapshot,
        previous: ProcessTableSnapshot
    ) -> UInt64 {
        guard
            let entry = current.entries[pid],
            let previousEntry = previous.entries[pid],
            previousEntry.startedAt == entry.startedAt,
            entry.cpuTimeNanoseconds >= previousEntry.cpuTimeNanoseconds
        else { return 0 }

        return entry.cpuTimeNanoseconds - previousEntry.cpuTimeNanoseconds
    }

    // Почему: таблица процессов строилась заново на каждый терминал и на каждую метрику
    public static func summary(
        roots: [Int32],
        current: ProcessTableSnapshot,
        previous: ProcessTableSnapshot?,
        elapsed: TimeInterval
    ) -> (usage: [Int32: ProcessTreeUsage], names: [Int32: Set<String>]) {
        var usage: [Int32: ProcessTreeUsage] = [:]
        var names: [Int32: Set<String>] = [:]

        let children = childrenByParent(in: current)

        for root in roots {
            let pids = subtreePIDs(ofRoot: root, children: children)

            usage[root] = self.usage(
                pids: pids,
                current: current,
                previous: previous,
                elapsed: elapsed
            )
            names[root] = Set(
                pids.compactMap { current.entries[$0]?.name }.filter { !$0.isEmpty }
            )
        }

        return (usage, names)
    }

    public static func usage(
        forSubtreeRoot root: Int32,
        current: ProcessTableSnapshot,
        previous: ProcessTableSnapshot?,
        elapsed: TimeInterval
    ) -> ProcessTreeUsage {
        usage(
            pids: subtreePIDs(ofRoot: root, in: current),
            current: current,
            previous: previous,
            elapsed: elapsed
        )
    }

    static func usage(
        pids: Set<Int32>,
        current: ProcessTableSnapshot,
        previous: ProcessTableSnapshot?,
        elapsed: TimeInterval
    ) -> ProcessTreeUsage {
        let memoryBytes = pids.reduce(UInt64(0)) {
            $0 + (current.entries[$1]?.residentMemoryBytes ?? 0)
        }

        guard let previous, elapsed > 0 else {
            return ProcessTreeUsage(cpuPercent: nil, memoryBytes: memoryBytes)
        }

        let deltaNanoseconds = pids.reduce(UInt64(0)) {
            $0 + delta(for: $1, current: current, previous: previous)
        }

        let cpuSeconds = Double(deltaNanoseconds) / 1_000_000_000
        let percent = (cpuSeconds / elapsed) * 100

        return ProcessTreeUsage(cpuPercent: percent, memoryBytes: memoryBytes)
    }
}
