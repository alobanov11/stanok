import AppKit
import GhosttyKit
import os

final class GhosttySurfaceView: NSView {

    override var acceptsFirstResponder: Bool { true }

    private var backingScale: CGFloat {
        let frame = convertToBacking(bounds)
        guard bounds.width > 0, frame.width > 0 else { return window?.backingScaleFactor ?? 2 }
        return frame.width / bounds.width
    }

    private var tracking: NSTrackingArea?

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
        config.scale_factor = 2
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
        applyScale()
        applySize(bounds.size)

        let link = displayLink(target: self, selector: #selector(render))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()

        applyScale()
        applySize(bounds.size)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        applyScale()
        applySize(newSize)
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
        guard let surface else { return }

        let mods = Self.mods(from: event.modifierFlags)
        let held = Self.modifier(for: event.keyCode).map { mods.rawValue & $0.rawValue != 0 } ?? false

        var key = ghostty_input_key_s()
        key.action = held ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE
        key.keycode = UInt32(event.keyCode)
        key.mods = mods
        key.consumed_mods = GHOSTTY_MODS_NONE
        key.composing = false
        key.unshifted_codepoint = 0
        key.text = nil
        _ = ghostty_surface_key(surface, key)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        sendMouse(event, state: GHOSTTY_MOUSE_PRESS, button: GHOSTTY_MOUSE_LEFT)
    }

    override func mouseUp(with event: NSEvent) {
        sendMouse(event, state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_LEFT)
    }

    override func rightMouseDown(with event: NSEvent) {
        sendMouse(event, state: GHOSTTY_MOUSE_PRESS, button: GHOSTTY_MOUSE_RIGHT)
    }

    override func rightMouseUp(with event: NSEvent) {
        sendMouse(event, state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_RIGHT)
    }

    override func mouseDragged(with event: NSEvent) {
        sendPosition(event)
    }

    override func mouseMoved(with event: NSEvent) {
        sendPosition(event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }

        var mods: Int32 = 0
        if event.hasPreciseScrollingDeltas { mods = 1 }
        if !event.momentumPhase.isEmpty { mods |= 2 }
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, mods)
    }

    private static func modifier(for keyCode: UInt16) -> ghostty_input_mods_e? {
        switch keyCode {
        case 56, 60: GHOSTTY_MODS_SHIFT
        case 59, 62: GHOSTTY_MODS_CTRL
        case 58, 61: GHOSTTY_MODS_ALT
        case 54, 55: GHOSTTY_MODS_SUPER
        case 57: GHOSTTY_MODS_CAPS
        default: nil
        }
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

    private func sendMouse(
        _ event: NSEvent,
        state: ghostty_input_mouse_state_e,
        button: ghostty_input_mouse_button_e
    ) {
        guard let surface else { return }

        sendPosition(event)
        _ = ghostty_surface_mouse_button(surface, state, button, Self.mods(from: event.modifierFlags))
    }

    private func sendPosition(_ event: NSEvent) {
        guard let surface else { return }

        let point = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(surface, point.x, bounds.height - point.y, Self.mods(from: event.modifierFlags))
    }

    private func applyScale() {
        guard let surface else { return }

        let scale = backingScale
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    private func applySize(_ size: NSSize) {
        guard let surface else { return }

        let scale = backingScale
        let backing = convertToBacking(NSRect(origin: .zero, size: size)).size
        ghostty_surface_set_size(surface, UInt32(max(backing.width, 1)), UInt32(max(backing.height, 1)))

        let metrics = ghostty_surface_size(surface)
        let cellWidth = Double(metrics.cell_width_px) / scale
        let cellHeight = Double(metrics.cell_height_px) / scale
        Log.terminal.info(
            "grid \(metrics.columns)x\(metrics.rows) cell \(cellWidth)x\(cellHeight)pt scale \(scale)"
        )
    }

}
