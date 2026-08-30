import StanokKit
import SwiftUI

public struct TerminalView: View {

    public var body: some View {
        TerminalSurface(
            runtime: runtime,
            workingDirectory: workingDirectory,
            isActive: isActive,
            onCommandFinished: onCommandFinished
        )
    }

    private let runtime: GhosttyRuntime

    private let workingDirectory: URL?

    private let isActive: Bool

    private let onCommandFinished: (CommandRun) -> Void

    public init(
        runtime: GhosttyRuntime,
        workingDirectory: URL?,
        isActive: Bool,
        onCommandFinished: @escaping (CommandRun) -> Void
    ) {
        self.runtime = runtime
        self.workingDirectory = workingDirectory
        self.isActive = isActive
        self.onCommandFinished = onCommandFinished
    }
}
