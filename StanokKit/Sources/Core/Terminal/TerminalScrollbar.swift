import Foundation

public struct TerminalScrollbar: Equatable, Sendable {

    public var isScrollable: Bool {
        total > length && length > 0
    }

    public var thumbFraction: Double {
        guard total > 0 else { return 1 }

        return min(Double(length) / Double(total), 1)
    }

    public var position: Double {
        let travel = total - length
        guard travel > 0 else { return 0 }

        return min(Double(offset) / Double(travel), 1)
    }

    public let total: UInt64
    public let offset: UInt64
    public let length: UInt64

    public init(total: UInt64, offset: UInt64, length: UInt64) {
        self.total = total
        self.offset = offset
        self.length = length
    }
}
