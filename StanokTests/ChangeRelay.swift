import Foundation

final class ChangeRelay: @unchecked Sendable {

    private let lock = NSLock()
    private var handler: (@Sendable () -> Void)?

    func store(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        self.handler = handler
    }

    func fire() {
        lock.lock()
        let handler = handler
        lock.unlock()

        handler?()
    }
}
