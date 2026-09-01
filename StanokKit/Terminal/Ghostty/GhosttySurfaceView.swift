import AppKit
import GhosttyKit
import os
import QuartzCore
import StanokKit

final class GhosttySurfaceView: NSView {

    private static let resizeInterval: CFTimeInterval = 0.03

    override var acceptsFirstResponder: Bool {
        true
    }

    var handle: ghostty_surface_t? {
        surface
    }

    private var backingScale: CGFloat {
        let frame = convertToBacking(bounds)
        guard bounds.width > 0, frame.width > 0 else { return window?.backingScaleFactor ?? 2 }
        return frame.width / bounds.width
    }

    var onCommandFinished: ((CommandRun) -> Void)?
    var onOpenURL: ((String) -> Void)?
    var onTitleChanged: ((String) -> Void)?
    var onCloseRequested: ((Bool) -> Void)?
    var onPwdChanged: ((String) -> Void)?
    var onFocused: (() -> Void)?
    var onScrollbarChanged: ((TerminalScrollbar) -> Void)?

    private var tracking: NSTrackingArea?
    private var desiredCursor = NSCursor.iBeam
    private var surface: ghostty_surface_t?
    private var link: CADisplayLink?
    private var isVisible = false
    private var visibilityApplied = false
    private var isFocused = false
    private var pendingSize = NSSize.zero
    private var appliedSize: (width: UInt32, height: UInt32) = (0, 0)
    private var resizeWork: DispatchWorkItem?
    private var lastResizeAt: CFTimeInterval = 0
    private var heldModifierKeys: [UInt16: ghostty_input_mods_e] = [:]
    private var lastHandledInsertRequestID: UUID?

    init(app: ghostty_app_t, fontSize: Float, workingDirectory: URL?, processLabel: String) {
        super.init(frame: .zero)

        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        var config = ghostty_surface_config_new()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(
            macos: ghostty_platform_macos_s(nsview: Unmanaged.passUnretained(self).toOpaque())
        )
        config.scale_factor = 1
        config.font_size = fontSize
        config.userdata = Unmanaged.passUnretained(self).toOpaque()

        self.surface = GhosttySurfaceConfigBuilder.makeSurface(
            app: app,
            config: &config,
            workingDirectory: workingDirectory,
            processLabel: processLabel
        )

        if surface == nil {
            Log.terminal.error("failed to create ghostty surface")
            showCreationFailureLabel()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not supported")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        link?.invalidate()
        link = nil

        guard let window else { return }

        if isFocused {
            DispatchQueue.main.async { [weak self] in
                guard let self, isFocused, self.window === window else { return }
                window.makeFirstResponder(self)
            }
        }

        applyScale()
        pendingSize = bounds.size
        applyPendingSize()

        let link = displayLink(target: self, selector: #selector(render))
        link.isPaused = !isVisible
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseMoved, .mouseEnteredAndExited, .cursorUpdate,
                .activeInKeyWindow, .inVisibleRect
            ],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func cursorUpdate(with event: NSEvent) {
        desiredCursor.set()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()

        applyScale()
        pendingSize = bounds.size
        applyPendingSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        applyScale()
        scheduleSize(newSize)
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()

        resizeWork?.cancel()
        resizeWork = nil
        applyPendingSize()
    }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }

        if let surface {
            ghostty_surface_set_focus(surface, true)
        }

        if !isFocused { onFocused?() }

        return true
    }

    override func resignFirstResponder() -> Bool {
        guard super.resignFirstResponder() else { return false }

        heldModifierKeys.removeAll()
        if let surface {
            ghostty_surface_set_focus(surface, false)
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        send(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
    }

    override func keyUp(with event: NSEvent) {
        send(event, action: GHOSTTY_ACTION_RELEASE)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface else { return }

        let keyCode = event.keyCode
        let action: ghostty_input_action_e
        if heldModifierKeys[keyCode] != nil {
            heldModifierKeys[keyCode] = nil
            action = GHOSTTY_ACTION_RELEASE
        } else {
            guard let category = Self.modifier(for: keyCode, flags: event.modifierFlags) else {
                return
            }
            heldModifierKeys[keyCode] = category
            action = GHOSTTY_ACTION_PRESS
        }

        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(keyCode)
        key.mods = Self.mods(from: event.modifierFlags)
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
        guard let surface, ghostty_surface_mouse_captured(surface) else {
            showContextMenu(with: event)
            return
        }

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
        mods |= Int32(momentumCode(event.momentumPhase)) << 1
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, mods)
    }

    static func from(surface: ghostty_surface_t) -> GhosttySurfaceView? {
        from(userdata: ghostty_surface_userdata(surface))
    }

    static func from(userdata: UnsafeMutableRawPointer?) -> GhosttySurfaceView? {
        guard let userdata else { return nil }
        return Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
    }

    func scroll(rows: Int) {
        guard let surface, rows != 0 else { return }

        ghostty_surface_mouse_scroll(surface, 0, Double(-rows), 0)
    }

    func updateScrollbar(_ scrollbar: TerminalScrollbar) {
        onScrollbarChanged?(scrollbar)
    }

    func setVisible(_ visible: Bool) {
        guard !visibilityApplied || isVisible != visible else { return }

        visibilityApplied = true
        isVisible = visible
        isHidden = !visible
        link?.isPaused = !visible

        if visible {
            scheduleSize(bounds.size)
        }

        if let surface {
            ghostty_surface_set_occlusion(surface, visible)
            if visible { ghostty_surface_refresh(surface) }
        }
    }

    func setFocused(_ focused: Bool) {
        guard isFocused != focused else { return }

        isFocused = focused

        if focused {
            DispatchQueue.main.async { [weak self] in
                guard let self, isFocused else { return }
                guard let window, window.firstResponder !== self else { return }

                window.makeFirstResponder(self)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, !isFocused else { return }
            guard let window, window.firstResponder === self else { return }

            window.makeFirstResponder(window.contentView)
        }
    }

    func setCursorShape(_ shape: ghostty_action_mouse_shape_e) {
        guard !isHidden else { return }

        let cursor = GhosttyCursorShape.cursor(for: shape)
        desiredCursor = cursor
        cursor.set()
    }

    func shutdown() {
        resizeWork?.cancel()
        resizeWork = nil
        link?.invalidate()
        link = nil

        if let surface {
            ghostty_surface_free(surface)
        }
        surface = nil
    }

    func apply(insertRequest: TerminalInsertRequest?) {
        guard let insertRequest, insertRequest.id != lastHandledInsertRequestID else { return }

        lastHandledInsertRequestID = insertRequest.id
        insert(insertRequest.text)
    }

    private func momentumCode(_ phase: NSEvent.Phase) -> UInt32 {
        switch phase {
        case .began: GHOSTTY_MOUSE_MOMENTUM_BEGAN.rawValue
        case .stationary: GHOSTTY_MOUSE_MOMENTUM_STATIONARY.rawValue
        case .changed: GHOSTTY_MOUSE_MOMENTUM_CHANGED.rawValue
        case .ended: GHOSTTY_MOUSE_MOMENTUM_ENDED.rawValue
        case .cancelled: GHOSTTY_MOUSE_MOMENTUM_CANCELLED.rawValue
        case .mayBegin: GHOSTTY_MOUSE_MOMENTUM_MAY_BEGIN.rawValue
        default: GHOSTTY_MOUSE_MOMENTUM_NONE.rawValue
        }
    }
}

private extension GhosttySurfaceView {

    static func insertableText(
        from event: NSEvent,
        using keyPath: KeyPath<NSEvent, String?>
    ) -> String? {
        guard let characters = event[keyPath: keyPath], !characters.isEmpty else { return nil }

        for scalar in characters.unicodeScalars {
            let isFunctionKey = (0xF700...0xF8FF).contains(scalar.value)
            let isControl = scalar.value < 0x20 || scalar.value == 0x7F
            if isFunctionKey || isControl { return nil }
        }
        return characters
    }

    static func modifier(
        for keyCode: UInt16,
        flags: NSEvent.ModifierFlags
    ) -> ghostty_input_mods_e? {
        switch keyCode {
        case 56, 60: GHOSTTY_MODS_SHIFT
        case 59, 62: GHOSTTY_MODS_CTRL
        case 58, 61: GHOSTTY_MODS_ALT
        case 54, 55: GHOSTTY_MODS_SUPER
        case 57: capsLockModifier(from: flags)
        default: nil
        }
    }

    static func capsLockModifier(
        from flags: NSEvent.ModifierFlags
    ) -> ghostty_input_mods_e {
        if flags.contains(.control) { return GHOSTTY_MODS_CTRL }
        if flags.contains(.option) { return GHOSTTY_MODS_ALT }
        if flags.contains(.command) { return GHOSTTY_MODS_SUPER }
        return GHOSTTY_MODS_CAPS
    }

    static func mods(from flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var raw = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { raw |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { raw |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { raw |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { raw |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { raw |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(raw)
    }

    @objc
    func render() {
        guard let surface else { return }
        ghostty_surface_draw(surface)
    }

    func send(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }

        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(event.keyCode)
        key.mods = Self.mods(from: event.modifierFlags)
        key.consumed_mods = GHOSTTY_MODS_NONE
        key.composing = false
        key.unshifted_codepoint = Self.insertableText(
            from: event,
            using: \.charactersIgnoringModifiers
        )?
            .unicodeScalars.first?.value ?? 0

        let text = event
            .type == .keyDown ? (Self.insertableText(from: event, using: \.characters) ?? "") : ""
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

    func sendMouse(
        _ event: NSEvent,
        state: ghostty_input_mouse_state_e,
        button: ghostty_input_mouse_button_e
    ) {
        guard let surface else { return }

        sendPosition(event)
        _ = ghostty_surface_mouse_button(
            surface,
            state,
            button,
            Self.mods(from: event.modifierFlags)
        )
    }

    func sendPosition(_ event: NSEvent) {
        guard let surface else { return }

        let point = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(
            surface,
            point.x,
            bounds.height - point.y,
            Self.mods(from: event.modifierFlags)
        )
    }

    func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()

        let copyItem = menu.addItem(
            withTitle: "Копировать",
            action: #selector(copySelection),
            keyEquivalent: ""
        )
        copyItem.target = self
        copyItem.isEnabled = surface.map { ghostty_surface_has_selection($0) } ?? false

        let pasteItem = menu.addItem(
            withTitle: "Вставить",
            action: #selector(pasteFromClipboard),
            keyEquivalent: ""
        )
        pasteItem.target = self

        let selectAllItem = menu.addItem(
            withTitle: "Выделить всё",
            action: #selector(selectAllText),
            keyEquivalent: ""
        )
        selectAllItem.target = self

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc
    func copySelection() {
        performBindingAction("copy_to_clipboard")
    }

    @objc
    func pasteFromClipboard() {
        performBindingAction("paste_from_clipboard")
    }

    func insert(_ text: String) {
        guard surface != nil, !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        performBindingAction("paste_from_clipboard")

        pasteboard.clearContents()
        if !saved.isEmpty { pasteboard.writeObjects(saved) }
    }

    @objc
    func selectAllText() {
        performBindingAction("select_all")
    }

    func performBindingAction(_ name: String) {
        guard let surface else { return }
        _ = name.withCString { ghostty_surface_binding_action(surface, $0, UInt(name.utf8.count)) }
    }

    func applyScale() {
        guard let surface else { return }

        let scale = backingScale
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    func scheduleSize(_ size: NSSize) {
        pendingSize = size
        guard isVisible else { return }

        let now = CACurrentMediaTime()
        guard now - lastResizeAt < Self.resizeInterval else {
            applyPendingSize()
            return
        }

        guard resizeWork == nil else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.resizeWork = nil
            self?.applyPendingSize()
        }
        resizeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.resizeInterval, execute: work)
    }

    func applyPendingSize() {
        lastResizeAt = CACurrentMediaTime()
        applySize(pendingSize)
    }

    func applySize(_ size: NSSize) {
        guard let surface, size.width > 1, size.height > 1 else { return }

        let backing = convertToBacking(NSRect(origin: .zero, size: size)).size
        let width = UInt32(max(backing.width, 1))
        let height = UInt32(max(backing.height, 1))
        guard (width, height) != appliedSize else { return }

        appliedSize = (width, height)
        ghostty_surface_set_size(surface, width, height)
    }

    func showCreationFailureLabel() {
        let label = NSTextField(labelWithString: "Не удалось создать поверхность терминала")
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
