import AppKit
import GhosttyKit
import os

final class GhosttySurfaceView: NSView {

    override var acceptsFirstResponder: Bool { true }

    private var surface: ghostty_surface_t?

    private var link: CADisplayLink?

    init(app: ghostty_app_t, fontSize: Float) {
        super.init(frame: .zero)

        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize

        var config = ghostty_surface_config_new()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(nsview: Unmanaged.passUnretained(self).toOpaque())
        )
        config.scale_factor = Double(window?.backingScaleFactor ?? 2)
        config.font_size = fontSize
        self.surface = ghostty_surface_new(app, &config)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else {
            link?.invalidate()
            link = nil
            return
        }

        applyScale(window.backingScaleFactor)
        applySize(bounds.size, scale: window.backingScaleFactor)

        let link = displayLink(target: self, selector: #selector(render))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()

        guard let scale = window?.backingScaleFactor else { return }
        applyScale(scale)
        applySize(bounds.size, scale: scale)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        applySize(newSize, scale: window?.backingScaleFactor ?? 2)
    }

    override func becomeFirstResponder() -> Bool {
        guard let surface else { return false }
        ghostty_surface_set_focus(surface, true)
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        guard let surface else { return false }
        ghostty_surface_set_focus(surface, false)
        return super.resignFirstResponder()
    }

    func shutdown() {
        link?.invalidate()
        link = nil

        if let surface {
            ghostty_surface_free(surface)
        }
        surface = nil
    }

    @objc
    private func render() {
        guard let surface else { return }
        ghostty_surface_draw(surface)
    }

    private func applyScale(_ scale: CGFloat) {
        guard let surface else { return }
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    private func applySize(_ size: NSSize, scale: CGFloat) {
        guard let surface else { return }
        let width = UInt32(max(size.width * scale, 1))
        let height = UInt32(max(size.height * scale, 1))
        ghostty_surface_set_size(surface, width, height)
    }
}
