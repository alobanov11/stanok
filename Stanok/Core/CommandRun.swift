import Foundation

struct CommandRun: Identifiable, Equatable {

    var succeeded: Bool { exitCode == 0 }

    let id = UUID()

    let exitCode: Int?

    let duration: Duration

    let finishedAt: Date

    init(exitCode: Int16, durationNanoseconds: UInt64, finishedAt: Date = .now) {
        self.exitCode = exitCode < 0 ? nil : Int(exitCode)
        self.duration = .nanoseconds(durationNanoseconds)
        self.finishedAt = finishedAt
    }
}
