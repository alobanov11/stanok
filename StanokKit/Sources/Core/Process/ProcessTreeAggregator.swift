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

    public static func usage(
        forSubtreeRoot root: Int32,
        current: ProcessTableSnapshot,
        previous: ProcessTableSnapshot?,
        elapsed: TimeInterval
    ) -> ProcessTreeUsage {
        let pids = subtreePIDs(ofRoot: root, in: current)
        let memoryBytes = pids.reduce(UInt64(0)) {
            $0 + (current.entries[$1]?.residentMemoryBytes ?? 0)
        }

        guard let previous, elapsed > 0 else {
            return ProcessTreeUsage(cpuPercent: nil, memoryBytes: memoryBytes)
        }

        var deltaNanoseconds: UInt64 = 0
        for pid in pids {
            guard
                let entry = current.entries[pid],
                let previousEntry = previous.entries[pid],
                previousEntry.startedAt == entry.startedAt,
                entry.cpuTimeNanoseconds >= previousEntry.cpuTimeNanoseconds
            else { continue }

            deltaNanoseconds += entry.cpuTimeNanoseconds - previousEntry.cpuTimeNanoseconds
        }

        let cpuSeconds = Double(deltaNanoseconds) / 1_000_000_000
        let percent = (cpuSeconds / elapsed) * 100

        return ProcessTreeUsage(cpuPercent: percent, memoryBytes: memoryBytes)
    }
}
