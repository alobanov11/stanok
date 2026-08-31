import Foundation

public struct ProcessSubtreeTotals: Equatable, Sendable {

    public let cpuTimeNanoseconds: UInt64
    public let residentMemoryBytes: UInt64

    public init(cpuTimeNanoseconds: UInt64, residentMemoryBytes: UInt64) {
        self.cpuTimeNanoseconds = cpuTimeNanoseconds
        self.residentMemoryBytes = residentMemoryBytes
    }
}
