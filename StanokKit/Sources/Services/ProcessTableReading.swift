import Foundation

public protocol ProcessTableReading: Sendable {

    func snapshot() async -> ProcessTableSnapshot
}
