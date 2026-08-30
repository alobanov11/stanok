import AppKit
import SwiftUI

struct TrafficLights: NSViewRepresentable {

    private static let types: [NSWindow.ButtonType] = [
        .closeButton,
        .miniaturizeButton,
        .zoomButton
    ]

    let isHidden: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        let hidden = isHidden

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            for type in Self.types {
                window.standardWindowButton(type)?.isHidden = hidden
            }
        }
    }
}
