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
    let onFocused: () -> Void
    let onScrollbar: (TerminalScrollbar) -> Void
    let scrollController: TerminalScrollController

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
        view.onFocused = onFocused
        view.onScrollbarChanged = onScrollbar
        scrollController.scroll = { [weak view] rows in view?.scroll(rows: rows) }
        view.apply(insertRequest: insertRequest)
        return view
    }

    func updateNSView(_ view: GhosttySurfaceView, context: Context) {
        view.onCommandFinished = onCommandFinished
        view.onOpenURL = onOpenURL
        view.onTitleChanged = onTitleChanged
        view.onCloseRequested = onCloseRequested
        view.onPwdChanged = onPwdChanged
        view.onFocused = onFocused
        view.onScrollbarChanged = onScrollbar
        scrollController.scroll = { [weak view] rows in view?.scroll(rows: rows) }
        view.setVisible(isVisible)
        view.setFocused(isFocused)
        view.apply(insertRequest: insertRequest)
    }
}
