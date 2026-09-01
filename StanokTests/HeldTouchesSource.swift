import Foundation

import StanokKit

actor HeldTouchesSource: AgentTouchesSource {

    private(set) var callCount = 0

    private var held: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var isStarted = false
    private var isReleased = false

    func touched(scope: String?) async -> (files: [AgentTouchedFile], directories: Set<String>) {
        callCount += 1
        isStarted = true
        started?.resume()
        started = nil

        if !isReleased {
            await withCheckedContinuation { held = $0 }
        }

        return ([], [])
    }

    func waitUntilStarted() async {
        guard !isStarted else { return }

        await withCheckedContinuation { started = $0 }
    }

    func release() {
        isReleased = true
        held?.resume()
        held = nil
    }
}
