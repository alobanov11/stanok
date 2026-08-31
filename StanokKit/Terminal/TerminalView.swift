import StanokKit
import SwiftUI

public struct TerminalView: View {

    public var body: some View {
        TerminalSurface(
            runtime: runtime,
            workingDirectory: workingDirectory,
            isActive: isActive,
            insertRequest: insertRequest,
            onCommandFinished: onCommandFinished,
            onOpenURL: onOpenURL,
            onTitleChanged: onTitleChanged,
            onCloseRequested: onCloseRequested
        )
    }

    private let runtime: GhosttyRuntime

    private let workingDirectory: URL?

    private let isActive: Bool

    private let insertRequest: TerminalInsertRequest?

    private let onCommandFinished: (CommandRun) -> Void

    private let onOpenURL: (String) -> Void

    private let onTitleChanged: (String) -> Void

    private let onCloseRequested: (Bool) -> Void

    public init(
        runtime: GhosttyRuntime,
        workingDirectory: URL?,
        isActive: Bool,
        insertRequest: TerminalInsertRequest? = nil,
        onCommandFinished: @escaping (CommandRun) -> Void,
        onOpenURL: @escaping (String) -> Void,
        onTitleChanged: @escaping (String) -> Void = { _ in },
        onCloseRequested: @escaping (Bool) -> Void = { _ in }
    ) {
        self.runtime = runtime
        self.workingDirectory = workingDirectory
        self.isActive = isActive
        self.insertRequest = insertRequest
        self.onCommandFinished = onCommandFinished
        self.onOpenURL = onOpenURL
        self.onTitleChanged = onTitleChanged
        self.onCloseRequested = onCloseRequested
    }
}
