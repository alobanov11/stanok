import GhosttyKit
import StanokKit
import SwiftUI

struct TerminalView: NSViewRepresentable {

    let runtime: GhosttyRuntime

    let workingDirectory: URL?

    let isActive: Bool

    let onCommandFinished: (CommandRun) -> Void

    static func dismantleNSView(_ view: GhosttySurfaceView, coordinator: ()) {
        view.shutdown()
    }

    func makeNSView(context: Context) -> GhosttySurfaceView {
        let fontSize = runtime.config.float("font-size") ?? 13
        let view = GhosttySurfaceView(
            app: runtime.app,
            fontSize: fontSize,
            workingDirectory: workingDirectory
        )
        view.onCommandFinished = onCommandFinished
        runtime.register(view)
        return view
    }

    func updateNSView(_ view: GhosttySurfaceView, context: Context) {
        view.onCommandFinished = onCommandFinished
        view.setActive(isActive)
    }
}
