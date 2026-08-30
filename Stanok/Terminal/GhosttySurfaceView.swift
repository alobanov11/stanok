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

        window.makeFirstResponder(self)
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

    override func keyDown(with event: NSEvent) {
        send(event, action: GHOSTTY_ACTION_PRESS)
    }

    override func keyUp(with event: NSEvent) {
        send(event, action: GHOSTTY_ACTION_RELEASE)
    }

    override func flagsChanged(with event: NSEvent) {
        send(event, action: GHOSTTY_ACTION_PRESS)
    }

    private static func mods(from flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var raw = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { raw |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { raw |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { raw |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { raw |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { raw |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(raw)
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

    private func send(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }

        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(event.keyCode)
        key.mods = Self.mods(from: event.modifierFlags)
        key.consumed_mods = GHOSTTY_MODS_NONE
        key.composing = false
        key.unshifted_codepoint = event.charactersIgnoringModifiers?.unicodeScalars.first?.value ?? 0

        let text = event.type == .keyDown ? (event.characters ?? "") : ""
        if text.isEmpty {
            key.text = nil
            _ = ghostty_surface_key(surface, key)
        } else {
            text.withCString { pointer in
                key.text = pointer
                _ = ghostty_surface_key(surface, key)
            }
        }
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
