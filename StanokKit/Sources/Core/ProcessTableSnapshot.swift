import Foundation

public struct ProcessTableSnapshot: Equatable, Sendable {

    public let entries: [Int32: ProcessTableEntry]

    public init(entries: [Int32: ProcessTableEntry]) {
        self.entries = entries
    }
}
