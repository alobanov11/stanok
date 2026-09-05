import AppKit
import Foundation

@MainActor
@Observable
public final class TerminalCommandDispatcher {

    public struct CopyNotice: Equatable {

        public let sessionID: TerminalSession.ID?

        let token: UUID
    }

    public private(set) var copyNotice: CopyNotice?

    private(set) var insertRequests: [TerminalSession.ID: TerminalInsertRequest] = [:]
    private(set) var closeRequests: [TerminalSession.ID: UUID] = [:]

    private var confirmedIdle: Set<TerminalSession.ID> = []

    public nonisolated init() {}

    public func markAtPrompt(_ id: TerminalSession.ID) {
        confirmedIdle.insert(id)
    }

    public func markInserted(_ id: TerminalSession.ID, request: UUID) {
        guard insertRequests[id]?.id == request else { return }

        insertRequests[id] = nil
    }

    public func markBusy(_ id: TerminalSession.ID) {
        confirmedIdle.remove(id)
    }

    public func forget(_ id: TerminalSession.ID) {
        confirmedIdle.remove(id)
        insertRequests[id] = nil
        closeRequests[id] = nil
    }

    public func insertRequest(for id: TerminalSession.ID) -> TerminalInsertRequest? {
        insertRequests[id]
    }

    public func closeRequest(for id: TerminalSession.ID) -> UUID? {
        closeRequests[id]
    }

    public func requestSurfaceClose(_ id: TerminalSession.ID) {
        closeRequests[id] = UUID()
    }

    public func markCloseHandled(_ id: TerminalSession.ID, request: UUID) {
        guard closeRequests[id] == request else { return }

        closeRequests[id] = nil
    }

    public func copy(
        _ action: AgentResumeAction,
        for sessionID: TerminalSession.ID?,
        runningProcessNames: Set<String> = []
    ) {
        write(resolvedCommand(for: action, runningProcessNames: runningProcessNames))
        announceCopy(for: sessionID)
    }

    // Почему: правка из превью попадает в активный терминал как текст, без запуска команды
    public func insert(_ text: String, into sessionID: TerminalSession.ID?) {
        guard !text.isEmpty else { return }

        guard let sessionID else {
            write(text)
            announceCopy(for: nil)

            return
        }

        insertRequests[sessionID] = TerminalInsertRequest(text: text)
    }

    public func dispatch(
        _ action: AgentResumeAction,
        into sessionID: TerminalSession.ID?,
        runningProcessNames: Set<String> = []
    ) {
        let command = resolvedCommand(for: action, runningProcessNames: runningProcessNames)
        write(command)

        guard let sessionID, confirmedIdle.contains(sessionID) else {
            announceCopy(for: sessionID)
            return
        }

        confirmedIdle.remove(sessionID)
        insertRequests[sessionID] = TerminalInsertRequest(text: command, submits: true)
    }
}

private extension TerminalCommandDispatcher {

    func resolvedCommand(
        for action: AgentResumeAction,
        runningProcessNames: Set<String>
    ) -> String {
        if
            let runningProcessName = action.runningProcessName,
            let inSessionText = action.inSessionText,
            runningProcessNames.contains(runningProcessName) {
            return inSessionText
        }

        let launch = ShellQuoting.posixQuote([action.executable] + action.arguments)
        guard let directory = action.workingDirectory else { return launch }

        let path = ShellQuoting.posixQuote([directory.path(percentEncoded: false)])

        return "cd \(path) && \(launch)"
    }

    func write(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func announceCopy(for sessionID: TerminalSession.ID?) {
        let token = UUID()
        copyNotice = CopyNotice(sessionID: sessionID, token: token)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, copyNotice?.token == token else { return }

            copyNotice = nil
        }
    }
}
