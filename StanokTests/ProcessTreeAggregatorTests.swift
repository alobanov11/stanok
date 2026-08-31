import Foundation
import Testing

import StanokKit

struct ProcessTreeAggregatorTests {

    @Test
    func subtreeSummationIncludesTheRootAndDescendantsButExcludesForeignBranches() {
        let root = entry(pid: 1, parentPID: 0, residentMemoryBytes: 10)
        let child = entry(pid: 2, parentPID: 1, residentMemoryBytes: 20)
        let grandchild = entry(pid: 3, parentPID: 2, residentMemoryBytes: 30)
        let foreignParent = entry(pid: 50, parentPID: 0, residentMemoryBytes: 1000)
        let foreignChild = entry(pid: 51, parentPID: 50, residentMemoryBytes: 2000)

        let snapshot = ProcessTableSnapshot(entries: [
            1: root, 2: child, 3: grandchild, 50: foreignParent, 51: foreignChild
        ])

        let pids = ProcessTreeAggregator.subtreePIDs(ofRoot: 1, in: snapshot)
        #expect(pids == [1, 2, 3])

        let totals = ProcessTreeAggregator.totals(forSubtreeRoot: 1, in: snapshot)
        #expect(totals.residentMemoryBytes == 60)
    }

    @Test
    func cpuPercentIsComputedFromTheDeltaOfTwoSnapshotsOverTheElapsedTime() {
        let previous = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 1_000_000_000)
        ])
        let current = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 3_000_000_000)
        ])

        let usage = ProcessTreeAggregator.usage(
            forSubtreeRoot: 1,
            current: current,
            previous: previous,
            elapsed: 2
        )

        #expect(usage.cpuPercent == 100)
    }

    @Test
    func firstMeasurementWithNoPreviousSnapshotReportsNoCPUPercent() {
        let current = ProcessTableSnapshot(entries: [
            1: entry(
                pid: 1,
                parentPID: 0,
                cpuTimeNanoseconds: 5_000_000_000,
                residentMemoryBytes: 42
            )
        ])

        let usage = ProcessTreeAggregator.usage(
            forSubtreeRoot: 1,
            current: current,
            previous: nil,
            elapsed: 2
        )

        #expect(usage.cpuPercent == nil)
        #expect(usage.memoryBytes == 42)
    }

    @Test
    func aDecreasingCounterWithTheSameStartTimeIsClampedRatherThanGoingNegative() {
        let previous = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 9_000_000_000)
        ])
        let current = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 1_000_000_000)
        ])

        let usage = ProcessTreeAggregator.usage(
            forSubtreeRoot: 1,
            current: current,
            previous: previous,
            elapsed: 2
        )

        #expect(usage.cpuPercent == 0)
    }

    @Test
    func aChangedStartTimeIsTreatedAsADifferentProcessRatherThanDiffed() {
        let previous = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 9_000_000_000)
        ])
        let current = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 200, cpuTimeNanoseconds: 500_000_000)
        ])

        let usage = ProcessTreeAggregator.usage(
            forSubtreeRoot: 1,
            current: current,
            previous: previous,
            elapsed: 2
        )

        #expect(usage.cpuPercent == 0)
    }

    @Test
    func aProcessThatVanishedBetweenSnapshotsIsSkippedRatherThanFailingTheWalk() {
        let previous = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 1_000_000_000),
            2: entry(pid: 2, parentPID: 1, startedAt: 100, cpuTimeNanoseconds: 1_000_000_000)
        ])
        let current = ProcessTableSnapshot(entries: [
            1: entry(pid: 1, parentPID: 0, startedAt: 100, cpuTimeNanoseconds: 3_000_000_000)
        ])

        let usage = ProcessTreeAggregator.usage(
            forSubtreeRoot: 1,
            current: current,
            previous: previous,
            elapsed: 2
        )

        #expect(usage.cpuPercent == 100)
    }

    @Test
    func subtreeProcessNamesCollectsNamesFromTheRootAndDescendantsButExcludesForeignBranches() {
        let root = entry(pid: 1, parentPID: 0, name: "zsh")
        let child = entry(pid: 2, parentPID: 1, name: "claude")
        let unnamed = entry(pid: 3, parentPID: 2, name: "")
        let foreignParent = entry(pid: 50, parentPID: 0, name: "bash")

        let snapshot = ProcessTableSnapshot(entries: [
            1: root, 2: child, 3: unnamed, 50: foreignParent
        ])

        let names = ProcessTreeAggregator.subtreeProcessNames(ofRoot: 1, in: snapshot)
        #expect(names == ["zsh", "claude"])
    }

    @Test
    func aDeepChainDoesNotOverflowTheStackDuringTheIterativeWalk() {
        let depth = 20000
        var entries: [Int32: ProcessTableEntry] = [:]
        entries[0] = entry(pid: 0, parentPID: 0)
        for pid in Int32(1)...Int32(depth) {
            entries[pid] = entry(pid: pid, parentPID: pid - 1)
        }

        let snapshot = ProcessTableSnapshot(entries: entries)
        let pids = ProcessTreeAggregator.subtreePIDs(ofRoot: 0, in: snapshot)

        #expect(pids.count == depth + 1)
    }

    private func entry(
        pid: Int32,
        parentPID: Int32,
        name: String = "",
        startedAt: UInt64 = 1,
        cpuTimeNanoseconds: UInt64 = 0,
        residentMemoryBytes: UInt64 = 0
    ) -> ProcessTableEntry {
        ProcessTableEntry(
            pid: pid,
            parentPID: parentPID,
            name: name,
            startedAt: startedAt,
            cpuTimeNanoseconds: cpuTimeNanoseconds,
            residentMemoryBytes: residentMemoryBytes
        )
    }
}
