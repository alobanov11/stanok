import Foundation

actor ConcurrencyGate {

    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private let limit: Int

    init(limit: Int) {
        self.limit = max(1, limit)
        self.available = self.limit
    }

    func withPermit<T: Sendable>(_ operation: @Sendable () async -> T) async -> T {
        await acquire()
        let result = await operation()
        release()
        return result
    }

    private func acquire() async {
        if available > 0 {
            available -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            available += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
