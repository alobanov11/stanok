import StanokKit
import SwiftUI

public struct TerminalView: View {

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
            onFocused: onFocused
        )
    }

    private let runtime: GhosttyRuntime

    private let workingDirectory: URL?

    private let processLabel: String

    private let isVisible: Bool

    private let isFocused: Bool

    private let insertRequest: TerminalInsertRequest?

    private let onCommandFinished: (CommandRun) -> Void

    private let onOpenURL: (String) -> Void

    private let onTitleChanged: (String) -> Void

    private let onCloseRequested: (Bool) -> Void

    private let onPwdChanged: (String) -> Void

    private let onFocused: () -> Void

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
        onFocused: @escaping () -> Void = {}
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
        self.onFocused = onFocused
    }
}
