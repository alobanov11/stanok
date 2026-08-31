import Foundation

public struct ProcessTableEntry: Equatable, Sendable {

    public let pid: Int32

    public let parentPID: Int32

    public let startedAt: UInt64

    public let cpuTimeNanoseconds: UInt64

    public let residentMemoryBytes: UInt64

    public init(
        pid: Int32,
        parentPID: Int32,
        startedAt: UInt64,
        cpuTimeNanoseconds: UInt64,
        residentMemoryBytes: UInt64
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.startedAt = startedAt
        self.cpuTimeNanoseconds = cpuTimeNanoseconds
        self.residentMemoryBytes = residentMemoryBytes
    }
}
