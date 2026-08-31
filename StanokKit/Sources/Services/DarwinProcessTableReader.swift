import Darwin
import Foundation

public struct DarwinProcessTableReader: ProcessTableReading {

    public init() {}

    private static func captureSnapshot() -> ProcessTableSnapshot {
        var entries: [Int32: ProcessTableEntry] = [:]

        for pid in listAllPIDs() {
            guard let entry = readEntry(pid: pid) else { continue }

            entries[pid] = entry
        }

        return ProcessTableSnapshot(entries: entries)
    }

    private static func listAllPIDs() -> [Int32] {
        let requiredSize = proc_listallpids(nil, 0)
        guard requiredSize > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(requiredSize) * 2)
        let bytesUsed = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard bytesUsed > 0 else { return [] }

        let count = min(Int(bytesUsed) / MemoryLayout<Int32>.size, pids.count)
        return Array(pids.prefix(count))
    }

    private static func readEntry(pid: Int32) -> ProcessTableEntry? {
        var bsdInfo = proc_bsdinfo()
        let bsdSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, bsdSize) == bsdSize else {
            return nil
        }

        var taskInfo = proc_taskinfo()
        let taskSize = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskSize) == taskSize else {
            return nil
        }

        let name = withUnsafeBytes(of: &bsdInfo.pbi_comm) { buffer -> String in
            let bytes = buffer.bindMemory(to: CChar.self)
            guard bytes.contains(0), let baseAddress = bytes.baseAddress else { return "" }

            return String(cString: baseAddress)
        }

        return ProcessTableEntry(
            pid: pid,
            parentPID: Int32(bsdInfo.pbi_ppid),
            name: name,
            startedAt: bsdInfo.pbi_start_tvsec,
            cpuTimeNanoseconds: taskInfo.pti_total_user + taskInfo.pti_total_system,
            residentMemoryBytes: taskInfo.pti_resident_size
        )
    }

    public func snapshot() async -> ProcessTableSnapshot {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: Self.captureSnapshot())
            }
        }
    }
}
