import Foundation

public struct ProcessTreeUsage: Equatable, Sendable {

    public let cpuPercent: Double?
    public let memoryBytes: UInt64

    public init(cpuPercent: Double?, memoryBytes: UInt64) {
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
    }
}
