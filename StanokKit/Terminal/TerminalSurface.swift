import StanokKit
import SwiftUI

struct TerminalSurface: NSViewRepresentable {

    let runtime: GhosttyRuntime

    let workingDirectory: URL?

    let isActive: Bool

    let insertRequest: TerminalInsertRequest?

    let onCommandFinished: (CommandRun) -> Void

    let onOpenURL: (String) -> Void

    let onTitleChanged: (String) -> Void

    let onCloseRequested: (Bool) -> Void

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
        view.onOpenURL = onOpenURL
        view.onTitleChanged = onTitleChanged
        view.onCloseRequested = onCloseRequested
        runtime.register(view)
        view.apply(insertRequest: insertRequest)
        return view
    }

    func updateNSView(_ view: GhosttySurfaceView, context: Context) {
        view.onCommandFinished = onCommandFinished
        view.onOpenURL = onOpenURL
        view.onTitleChanged = onTitleChanged
        view.onCloseRequested = onCloseRequested
        view.setActive(isActive)
        view.apply(insertRequest: insertRequest)
    }
}
