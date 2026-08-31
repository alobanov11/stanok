import AppKit

final class TrafficLightsView: NSView {

    private static let types: [NSWindow.ButtonType] = [
        .closeButton,
        .miniaturizeButton,
        .zoomButton
    ]

    var hidesButtons = false {
        didSet { apply() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        apply()
    }

    private func apply() {
        guard let window else { return }

        for type in Self.types {
            window.standardWindowButton(type)?.isHidden = hidesButtons
        }
    }
}
