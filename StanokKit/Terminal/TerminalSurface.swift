import StanokKit
import SwiftUI

struct TerminalSurface: NSViewRepresentable {

    let runtime: GhosttyRuntime
    let workingDirectory: URL?
    let processLabel: String
    let isVisible: Bool
    let isFocused: Bool
    let insertRequest: TerminalInsertRequest?
    let onCommandFinished: (CommandRun) -> Void
    let onOpenURL: (String) -> Void
    let onTitleChanged: (String) -> Void
    let onCloseRequested: (Bool) -> Void
    let onPwdChanged: (String) -> Void
    let onInput: () -> Void
    let onInsertHandled: (UUID) -> Void
    let closeRequest: UUID?
    let onCloseHandled: (UUID) -> Void
    let onFocused: () -> Void
    let onScrollbar: (TerminalScrollbar) -> Void
    let scrollController: TerminalScrollController
    let snapshotController: TerminalSnapshotController

    static func dismantleNSView(_ view: GhosttySurfaceView, coordinator: ()) {
        view.shutdown()
    }

    func makeNSView(context: Context) -> GhosttySurfaceView {
        let fontSize = runtime.config.float("font-size") ?? 13
        let view = GhosttySurfaceView(
            app: runtime.app,
            fontSize: fontSize,
            workingDirectory: workingDirectory,
            processLabel: processLabel
        )
        view.onCommandFinished = onCommandFinished
        view.onOpenURL = onOpenURL
        view.onTitleChanged = onTitleChanged
        view.onCloseRequested = onCloseRequested
        view.onPwdChanged = onPwdChanged
        view.onInput = onInput
        view.onInsertHandled = onInsertHandled
        view.onCloseHandled = onCloseHandled
        view.onFocused = onFocused
        view.onScrollbarChanged = onScrollbar
        scrollController.scroll = { [weak view] row in view?.scroll(toRow: row) }
        snapshotController.read = { [weak view] in view?.viewportText() }
        view.apply(insertRequest: insertRequest)
        view.apply(closeRequest: closeRequest)
        return view
    }

    func updateNSView(_ view: GhosttySurfaceView, context: Context) {
        view.onCommandFinished = onCommandFinished
        view.onOpenURL = onOpenURL
        view.onTitleChanged = onTitleChanged
        view.onCloseRequested = onCloseRequested
        view.onPwdChanged = onPwdChanged
        view.onInput = onInput
        view.onInsertHandled = onInsertHandled
        view.onCloseHandled = onCloseHandled
        view.onFocused = onFocused
        view.onScrollbarChanged = onScrollbar
        scrollController.scroll = { [weak view] row in view?.scroll(toRow: row) }
        snapshotController.read = { [weak view] in view?.viewportText() }
        view.setVisible(to: isVisible)
        view.setFocused(to: isFocused)
        view.apply(insertRequest: insertRequest)
        view.apply(closeRequest: closeRequest)
    }
}
