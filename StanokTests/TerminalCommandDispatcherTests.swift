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
    func aWorkingDirectoryIsPrependedAsACdToTheLaunchForm() {
        let dispatcher = TerminalCommandDispatcher()
        let action = AgentResumeAction(
            executable: "claude",
            arguments: ["--resume", "abc"],
            workingDirectory: URL(filePath: "/Users/tom/Projects/my app")
        )
        dispatcher.dispatch(action, into: UUID())

        #expect(
            NSPasteboard.general.string(forType: .string)
                == "cd '/Users/tom/Projects/my app' && claude --resume abc"
        )
    }

    @Test
    func theInSessionFormNeverGetsACd() {
        let dispatcher = TerminalCommandDispatcher()
        let action = AgentResumeAction(
            executable: "claude",
            arguments: ["--resume", "abc"],
            runningProcessName: "claude",
            inSessionText: "/resume abc",
            workingDirectory: URL(filePath: "/Users/tom")
        )
        dispatcher.dispatch(action, into: UUID(), runningProcessNames: ["claude"])

        #expect(NSPasteboard.general.string(forType: .string) == "/resume abc")
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

    @Test
    func aDeliveredCommandIsForgotten() throws {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.markAtPrompt(session)
        dispatcher.dispatch(action("third"), into: session)

        let request = try #require(dispatcher.insertRequest(for: session))
        dispatcher.markInserted(session, request: request.id)

        #expect(dispatcher.insertRequest(for: session) == nil)
    }

    @Test
    func aForeignRequestIdLeavesTheCommandInPlace() {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.markAtPrompt(session)
        dispatcher.dispatch(action("fourth"), into: session)
        dispatcher.markInserted(session, request: UUID())

        #expect(dispatcher.insertRequest(for: session) != nil)
    }

    @Test
    func forgettingASessionDropsBothItsPromptStateAndItsCommand() {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.markAtPrompt(session)
        dispatcher.dispatch(action("fifth"), into: session)
        dispatcher.forget(session)
        dispatcher.dispatch(action("sixth"), into: session)

        #expect(dispatcher.insertRequest(for: session) == nil)
    }

    @Test
    func typingInTheTerminalMakesItBusyAgain() {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.markAtPrompt(session)
        dispatcher.markBusy(session)
        dispatcher.dispatch(action("seventh"), into: session)

        #expect(dispatcher.insertRequest(for: session) == nil)
    }

    @Test
    func anOldCloseAnswerDoesNotCancelANewRequest() throws {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.requestSurfaceClose(session)

        let first = try #require(dispatcher.closeRequest(for: session))
        dispatcher.requestSurfaceClose(session)
        dispatcher.markCloseHandled(session, request: first)

        #expect(dispatcher.closeRequest(for: session) != nil)
    }

    @Test
    func forgettingASessionDropsItsCloseRequest() {
        let dispatcher = TerminalCommandDispatcher()
        let session = UUID()
        dispatcher.requestSurfaceClose(session)
        dispatcher.forget(session)

        #expect(dispatcher.closeRequest(for: session) == nil)
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
