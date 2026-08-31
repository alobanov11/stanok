import Foundation

struct CwdGenerationTracker {

    private var generations: [TerminalSession.ID: Int] = [:]

    mutating func advance(for id: TerminalSession.ID) -> Int {
        let next = generations[id, default: 0] + 1
        generations[id] = next
        return next
    }

    func isCurrent(_ generation: Int, for id: TerminalSession.ID) -> Bool {
        generations[id] == generation
    }
}
