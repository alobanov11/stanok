import AppKit
import Foundation
import Testing

import StanokKit

@MainActor
struct TerminalCommandDispatcherTests {

    @Test
    func aBusySessionPutsTheCommandOnTheClipboard() {
        let dispatcher = TerminalCommandDispatcher()
        dispatcher.dispatch(action("first"), into: UUID())

        #expect(NSPasteboard.general.string(forType: .string) == "claude --resume first")
    }

    @Test
    func anIdleSessionAlsoPutsTheCommandOnTheClipboard() {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.markAtPrompt(session)
        dispatcher.dispatch(action("second"), into: session)

        #expect(dispatcher.insertRequest(for: session) != nil)
        #expect(NSPasteboard.general.string(forType: .string) == "claude --resume second")
    }

    @Test
    func asecondDispatchOverwritesTheFirst() {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.dispatch(action("old"), into: session)
        dispatcher.markAtPrompt(session)
        dispatcher.dispatch(action("new"), into: session)

        #expect(NSPasteboard.general.string(forType: .string) == "claude --resume new")
    }

    @Test
    func whenTheAgentIsAlreadyRunningInTheTabTheInSessionFormIsUsedVerbatim() {
        let dispatcher = TerminalCommandDispatcher()
        dispatcher.dispatch(
            resumableAction("third"),
            into: UUID(),
            runningProcessNames: ["zsh", "claude"]
        )

        #expect(NSPasteboard.general.string(forType: .string) == "/resume third")
    }

    @Test
    func whenTheAgentIsNotRunningInTheTabTheLaunchFormIsUsed() {
        let dispatcher = TerminalCommandDispatcher()
        dispatcher.dispatch(
            resumableAction("fourth"),
            into: UUID(),
            runningProcessNames: ["zsh"]
        )

        #expect(NSPasteboard.general.string(forType: .string) == "claude --resume fourth")
    }

    @Test
    func withNoRunningProcessNamesSuppliedTheLaunchFormIsUsed() {
        let dispatcher = TerminalCommandDispatcher()
        dispatcher.dispatch(resumableAction("fifth"), into: UUID())

        #expect(NSPasteboard.general.string(forType: .string) == "claude --resume fifth")
    }

    private func action(_ id: String) -> AgentResumeAction {
        AgentResumeAction(executable: "claude", arguments: ["--resume", id])
    }

    private func resumableAction(_ id: String) -> AgentResumeAction {
        AgentResumeAction(
            executable: "claude",
            arguments: ["--resume", id],
            runningProcessName: "claude",
            inSessionText: "/resume \(id)"
        )
    }

}
