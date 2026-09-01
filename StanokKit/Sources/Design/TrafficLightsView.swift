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

    private weak var hosting: NSWindow?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)

        restore()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        hosting = window
        apply()
    }

    func restore() {
        guard let hosting else { return }

        for type in Self.types {
            hosting.standardWindowButton(type)?.isHidden = false
        }

        self.hosting = nil
    }

    private func apply() {
        guard let window else { return }

        hosting = window
        for type in Self.types {
            window.standardWindowButton(type)?.isHidden = hidesButtons
        }
    }
}
