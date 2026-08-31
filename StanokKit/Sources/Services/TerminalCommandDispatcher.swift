import AppKit
import Foundation

@MainActor
@Observable
public final class TerminalCommandDispatcher {

    public struct CopyNotice: Equatable {

        public let sessionID: TerminalSession.ID

        let token: UUID
    }

    public private(set) var copyNotice: CopyNotice?

    private(set) var insertRequests: [TerminalSession.ID: TerminalInsertRequest] = [:]

    private var confirmedIdle: Set<TerminalSession.ID> = []

    public nonisolated init() {}

    public func markAtPrompt(_ id: TerminalSession.ID) {
        confirmedIdle.insert(id)
    }

    public func forget(_ id: TerminalSession.ID) {
        confirmedIdle.remove(id)
        insertRequests[id] = nil
    }

    public func insertRequest(for id: TerminalSession.ID) -> TerminalInsertRequest? {
        insertRequests[id]
    }

    public func dispatch(_ action: AgentResumeAction, into sessionID: TerminalSession.ID) {
        let command = ShellQuoting.posixQuote([action.executable] + action.arguments)
        guard confirmedIdle.contains(sessionID) else {
            copy(command, for: sessionID)
            return
        }

        confirmedIdle.remove(sessionID)
        insertRequests[sessionID] = TerminalInsertRequest(text: command)
    }

    private func copy(_ text: String, for sessionID: TerminalSession.ID) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let token = UUID()
        copyNotice = CopyNotice(sessionID: sessionID, token: token)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, copyNotice?.token == token else { return }

            copyNotice = nil
        }
    }
}
