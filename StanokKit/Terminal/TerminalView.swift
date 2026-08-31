import StanokKit
import SwiftUI

public struct TerminalView: View {

    public var body: some View {
        TerminalSurface(
            runtime: runtime,
            workingDirectory: workingDirectory,
            processLabel: processLabel,
            isActive: isActive,
            insertRequest: insertRequest,
            onCommandFinished: onCommandFinished,
            onOpenURL: onOpenURL,
            onTitleChanged: onTitleChanged,
            onCloseRequested: onCloseRequested,
            onPwdChanged: onPwdChanged
        )
    }

    private let runtime: GhosttyRuntime

    private let workingDirectory: URL?

    private let processLabel: String

    private let isActive: Bool

    private let insertRequest: TerminalInsertRequest?

    private let onCommandFinished: (CommandRun) -> Void

    private let onOpenURL: (String) -> Void

    private let onTitleChanged: (String) -> Void

    private let onCloseRequested: (Bool) -> Void

    private let onPwdChanged: (String) -> Void

    public init(
        runtime: GhosttyRuntime,
        workingDirectory: URL?,
        processLabel: String,
        isActive: Bool,
        insertRequest: TerminalInsertRequest? = nil,
        onCommandFinished: @escaping (CommandRun) -> Void,
        onOpenURL: @escaping (String) -> Void,
        onTitleChanged: @escaping (String) -> Void = { _ in },
        onCloseRequested: @escaping (Bool) -> Void = { _ in },
        onPwdChanged: @escaping (String) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.workingDirectory = workingDirectory
        self.processLabel = processLabel
        self.isActive = isActive
        self.insertRequest = insertRequest
        self.onCommandFinished = onCommandFinished
        self.onOpenURL = onOpenURL
        self.onTitleChanged = onTitleChanged
        self.onCloseRequested = onCloseRequested
        self.onPwdChanged = onPwdChanged
    }
}
