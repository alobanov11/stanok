import Foundation

@MainActor
struct AgentCommandRouter {

    let dispatcher: TerminalCommandDispatcher
    let tracker: TabProcessTracker

    func copy(_ action: AgentResumeAction, for sessionID: TerminalSession.ID?) {
        dispatcher.copy(action, for: sessionID, runningProcessNames: names(sessionID))
    }

    func insert(_ action: AgentResumeAction, into sessionID: TerminalSession.ID?) {
        dispatcher.dispatch(action, into: sessionID, runningProcessNames: names(sessionID))
    }

    private func names(_ sessionID: TerminalSession.ID?) -> Set<String> {
        sessionID.map(tracker.processNames) ?? []
    }
}
