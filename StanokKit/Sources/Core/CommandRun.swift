import Foundation

public struct CommandRun: Identifiable, Equatable {

    public var succeeded: Bool { exitCode == 0 }

    public let id = UUID()

    public let exitCode: Int?

    public let duration: Duration

    public let finishedAt: Date

    public init(exitCode: Int16, durationNanoseconds: UInt64, finishedAt: Date = .now) {
        self.exitCode = exitCode < 0 ? nil : Int(exitCode)
        self.duration = .nanoseconds(durationNanoseconds)
        self.finishedAt = finishedAt
    }
}
