import GhosttyKit
import SwiftUI

struct TerminalView: NSViewRepresentable {

    let runtime: GhosttyRuntime

    static func dismantleNSView(_ view: GhosttySurfaceView, coordinator: ()) {
        view.shutdown()
    }

    func makeNSView(context: Context) -> GhosttySurfaceView {
        let fontSize = runtime.config.float("font-size") ?? 13
        return GhosttySurfaceView(app: runtime.app, fontSize: fontSize)
    }

    func updateNSView(_ view: GhosttySurfaceView, context: Context) {}
}
