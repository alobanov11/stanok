import Foundation

@MainActor
@Observable
public final class AppResourceMonitor {

    public var usage: ProcessTreeUsage? {
        monitor.usage[pid]
    }

    private let monitor: ProcessTreeMonitor
    private let pid: Int32

    public init(monitor: ProcessTreeMonitor = ProcessTreeMonitor()) {
        self.monitor = monitor
        self.pid = ProcessInfo.processInfo.processIdentifier
    }

    public func start() {
        monitor.observe(pid)
    }
}
