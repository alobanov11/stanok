import Foundation

@MainActor
final class SaveScheduler<State: Equatable> {

    private var lastKnown: State?
    private var pendingWrite: State?
    private var task: Task<Void, Never>?

    private let delay: Duration
    private let write: (State) -> Bool

    init(delay: Duration = .milliseconds(400), write: @escaping (State) -> Bool) {
        self.delay = delay
        self.write = write
    }

    func schedule(_ state: State) {
        guard state != lastKnown else { return }

        lastKnown = state
        pendingWrite = state

        task?.cancel()
        task = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }

            self?.commit()
        }
    }

    func flush() {
        task?.cancel()
        task = nil
        commit()
    }

    private func commit() {
        guard let pendingWrite else { return }

        guard write(pendingWrite) else {
            lastKnown = nil
            return
        }

        self.pendingWrite = nil
    }
}
