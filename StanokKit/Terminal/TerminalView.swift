import StanokKit
import SwiftUI

public struct TerminalView: View {

    @State
    private var scrollController = TerminalScrollController()

    @State
    private var snapshotController = TerminalSnapshotController()

    public var body: some View {
        TerminalSurface(
            runtime: runtime,
            workingDirectory: workingDirectory,
            processLabel: processLabel,
            isVisible: isVisible,
            isFocused: isFocused,
            insertRequest: insertRequest,
            onCommandFinished: onCommandFinished,
            onOpenURL: onOpenURL,
            onTitleChanged: onTitleChanged,
            onCloseRequested: onCloseRequested,
            onPwdChanged: onPwdChanged,
            onInput: onInput,
            onInsertHandled: onInsertHandled,
            closeRequest: closeRequest,
            onCloseHandled: onCloseHandled,
            onFocused: onFocused,
            onScrollbar: scrollController.report,
            scrollController: scrollController,
            snapshotController: snapshotController
        )
        .overlay(alignment: .trailing) {
            TerminalScrollbarOverlay(controller: scrollController)
        }
        // Почему: миниатюра в полосе — это текст экрана, снятый раз в полторы секунды
        .task(id: wantsSnapshots) { await pollSnapshots() }
    }

    private let runtime: GhosttyRuntime
    private let workingDirectory: URL?
    private let processLabel: String
    private let isVisible: Bool
    private let isFocused: Bool
    private let wantsSnapshots: Bool
    private let insertRequest: TerminalInsertRequest?
    private let onCommandFinished: (CommandRun) -> Void
    private let onOpenURL: (String) -> Void
    private let onTitleChanged: (String) -> Void
    private let onCloseRequested: (Bool) -> Void
    private let onPwdChanged: (String) -> Void
    private let onInput: () -> Void
    private let onInsertHandled: (UUID) -> Void
    private let onCloseHandled: (UUID) -> Void
    private let onFocused: () -> Void
    private let onSnapshot: (String) -> Void
    private let closeRequest: UUID?

    public init(
        runtime: GhosttyRuntime,
        workingDirectory: URL?,
        processLabel: String,
        isVisible: Bool,
        isFocused: Bool,
        insertRequest: TerminalInsertRequest? = nil,
        onCommandFinished: @escaping (CommandRun) -> Void,
        onOpenURL: @escaping (String) -> Void,
        onTitleChanged: @escaping (String) -> Void = { _ in },
        onCloseRequested: @escaping (Bool) -> Void = { _ in },
        onPwdChanged: @escaping (String) -> Void = { _ in },
        onInput: @escaping () -> Void = {},
        onInsertHandled: @escaping (UUID) -> Void = { _ in },
        closeRequest: UUID? = nil,
        onCloseHandled: @escaping (UUID) -> Void = { _ in },
        onFocused: @escaping () -> Void = {},
        onSnapshot: @escaping (String) -> Void = { _ in },
        wantsSnapshots: Bool = false
    ) {
        self.runtime = runtime
        self.workingDirectory = workingDirectory
        self.processLabel = processLabel
        self.isVisible = isVisible
        self.isFocused = isFocused
        self.insertRequest = insertRequest
        self.onCommandFinished = onCommandFinished
        self.onOpenURL = onOpenURL
        self.onTitleChanged = onTitleChanged
        self.onCloseRequested = onCloseRequested
        self.onPwdChanged = onPwdChanged
        self.onInput = onInput
        self.onInsertHandled = onInsertHandled
        self.closeRequest = closeRequest
        self.onCloseHandled = onCloseHandled
        self.onFocused = onFocused
        self.onSnapshot = onSnapshot
        self.wantsSnapshots = wantsSnapshots
    }

    private func pollSnapshots() async {
        guard wantsSnapshots else { return }

        while !Task.isCancelled {
            if let text = snapshotController.read?() { onSnapshot(text) }

            try? await Task.sleep(for: .milliseconds(1500))
        }
    }
}
