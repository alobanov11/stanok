import AppKit
import GhosttyKit
import os
import QuartzCore
import StanokKit

final class GhosttySurfaceView: NSView {

    private enum Visibility {

        case unset
        case hidden
        case visible
    }

    private enum DeviceMask {

        static let byKeyCode: [UInt16: UInt] = [
            56: 0x02, 60: 0x04,
            59: 0x01, 62: 0x2000,
            58: 0x20, 61: 0x40,
            55: 0x08, 54: 0x10
        ]
    }

    private static let resizeInterval: CFTimeInterval = 0.03
    private static let settleInterval: CFTimeInterval = 0.12

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
    var onInput: (() -> Void)?
    var onInsertHandled: ((UUID) -> Void)?
    var onCloseHandled: ((UUID) -> Void)?
    var onOpenURL: ((String) -> Void)?
    var onTitleChanged: ((String) -> Void)?
    var onCloseRequested: ((Bool) -> Void)?
    var onPwdChanged: ((String) -> Void)?
    var onFocused: (() -> Void)?
    var onScrollbarChanged: ((TerminalScrollbar) -> Void)?

    private var tracking: NSTrackingArea?
    private var desiredCursor = NSCursor.iBeam
    private var surface: ghostty_surface_t?
    private var visibility = Visibility.unset
    private var isFocused = false
    private var pendingSize = NSSize.zero
    private var appliedSize: (width: UInt32, height: UInt32) = (0, 0)
    private var resizeWork: DispatchWorkItem?
    private var lastResizeAt: CFTimeInterval = 0
    private var lastHandledInsertRequestID: UUID?
    private var lastHandledCloseRequestID: UUID?

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

        if let surface {
            ghostty_surface_set_focus(surface, false)
        }
        return true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Почему: ⌘-сочетания AppKit забирает себе, и строковые правки не доходят до шелла
        guard window?.firstResponder === self, surface != nil, Self.isLineEditing(event) else {
            return false
        }

        keyDown(with: event)

        return true
    }

    override func keyDown(with event: NSEvent) {
        onInput?()
        send(event, action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS)
    }

    override func keyUp(with event: NSEvent) {
        send(event, action: GHOSTTY_ACTION_RELEASE)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface else { return }

        let keyCode = event.keyCode
        guard Self.modifier(for: keyCode) != nil else { return }

        let pressed = Self.isPressed(keyCode: keyCode, flags: event.modifierFlags)
        let action = pressed ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE

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

    override func mouseEntered(with event: NSEvent) {
        sendPosition(event)
    }

    override func mouseExited(with event: NSEvent) {
        guard let surface, NSEvent.pressedMouseButtons == 0 else { return }

        ghostty_surface_mouse_pos(surface, -1, -1, Self.mods(from: event.modifierFlags))
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

    func scroll(toRow row: Int) {
        // Почему: колесо ghostty умножает дельту на cell_size и множитель, строка — нет
        performBindingAction("scroll_to_row:\(max(row, 0))")
    }

    func updateScrollbar(_ scrollbar: TerminalScrollbar) {
        onScrollbarChanged?(scrollbar)
    }

    func setVisible(to visible: Bool) {
        let next: Visibility = visible ? .visible : .hidden
        guard visibility != next else { return }

        visibility = next
        isHidden = !visible

        if visible {
            scheduleSize(bounds.size)
        }

        if let surface {
            ghostty_surface_set_occlusion(surface, visible)
            if visible { ghostty_surface_refresh(surface) }
        }
    }

    func setFocused(to focused: Bool) {
        guard isFocused != focused else { return }

        isFocused = focused

        DispatchQueue.main.async { [weak self] in
            self?.applyFocus(to: focused)
        }
    }

    func applyFocus(to focused: Bool) {
        guard isFocused == focused, let window else { return }

        guard focused else {
            guard window.firstResponder === self else { return }

            window.makeFirstResponder(window.contentView)
            return
        }

        guard window.firstResponder !== self else { return }

        window.makeFirstResponder(self)
    }

    // Почему: миниатюра рисуется настоящим текстом экрана, Metal-слой для этого не снять
    func viewportText() -> String? {
        guard let surface else { return nil }

        var selection = ghostty_selection_s()
        selection.top_left = ghostty_point_s(
            tag: GHOSTTY_POINT_VIEWPORT,
            coord: GHOSTTY_POINT_COORD_TOP_LEFT,
            x: 0,
            y: 0
        )
        selection.bottom_right = ghostty_point_s(
            tag: GHOSTTY_POINT_VIEWPORT,
            coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT,
            x: 0,
            y: 0
        )
        selection.rectangle = false

        var text = ghostty_text_s()
        guard ghostty_surface_read_text(surface, selection, &text) else { return nil }

        defer { ghostty_surface_free_text(surface, &text) }

        guard let pointer = text.text else { return nil }

        return String(cString: pointer)
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

        if let surface {
            ghostty_surface_free(surface)
        }
        surface = nil
    }

    func apply(closeRequest: UUID?) {
        guard let closeRequest, closeRequest != lastHandledCloseRequestID else { return }

        lastHandledCloseRequestID = closeRequest

        let id = closeRequest
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            onCloseHandled?(id)

            guard let surface else {
                onCloseRequested?(false)
                return
            }

            ghostty_surface_request_close(surface)
        }
    }

    func apply(insertRequest: TerminalInsertRequest?) {
        guard let insertRequest, insertRequest.id != lastHandledInsertRequestID else { return }

        lastHandledInsertRequestID = insertRequest.id
        insert(insertRequest.text, submits: insertRequest.submits)

        let id = insertRequest.id
        DispatchQueue.main.async { [weak self] in self?.onInsertHandled?(id) }
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

    static func insertableText(from event: NSEvent) -> String? {
        guard
            let text = baseCharacters(from: event),
            let first = text.unicodeScalars.first,
            first.isInsertable
        else { return nil }

        return text
    }

    static func baseCharacters(from event: NSEvent) -> String? {
        guard let characters = event.characters, !characters.isEmpty else { return nil }

        // Почему: ghostty кодирует ctrl сам, ему нужен базовый символ, а не управляющий байт
        guard
            characters.unicodeScalars.count == 1,
            let scalar = characters.unicodeScalars.first,
            scalar.value < 0x20
        else { return characters }

        return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
    }

    static func modifier(for keyCode: UInt16) -> ghostty_input_mods_e? {
        switch keyCode {
        case 56, 60: GHOSTTY_MODS_SHIFT
        case 59, 62: GHOSTTY_MODS_CTRL
        case 58, 61: GHOSTTY_MODS_ALT
        case 54, 55: GHOSTTY_MODS_SUPER
        case 57: GHOSTTY_MODS_CAPS
        default: nil
        }
    }

    static func isPressed(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard let mask = DeviceMask.byKeyCode[keyCode] else {
            return flags.contains(.capsLock)
        }

        return flags.rawValue & mask != 0
    }

    static func unshifted(from event: NSEvent) -> UInt32 {
        guard
            let scalar = event.characters(byApplyingModifiers: [])?.unicodeScalars.first,
            !(0xF700...0xF8FF).contains(scalar.value)
        else { return 0 }

        return scalar.value
    }

    static func isLineEditing(_ event: NSEvent) -> Bool {
        let editing: Set<UInt16> = [51, 123, 124]
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        return mods == .command && editing.contains(event.keyCode)
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

    func send(_ event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }

        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(event.keyCode)
        key.mods = Self.mods(from: event.modifierFlags)
        key.consumed_mods = Self.mods(
            from: event.modifierFlags.subtracting([.control, .command])
        )
        key.composing = false
        key.unshifted_codepoint = Self.unshifted(from: event)

        let text = event.type == .keyDown ? (Self.insertableText(from: event) ?? "") : ""
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
        ghostty_surface_mouse_pos(surface, point.x, bounds.height - point.y, hoverMods(for: event))
    }

    func hoverMods(for event: NSEvent) -> ghostty_input_mods_e {
        let mods = Self.mods(from: event.modifierFlags)
        guard
            let surface,
            NSEvent.pressedMouseButtons == 0,
            !ghostty_surface_mouse_captured(surface)
        else { return mods }

        // Почему: ghostty ждёт ⌘ над ссылкой, а у нас её открывают обычным кликом
        return ghostty_input_mods_e(mods.rawValue | GHOSTTY_MODS_SUPER.rawValue)
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

    func insert(_ text: String, submits: Bool = false) {
        guard let surface, !text.isEmpty else { return }

        let executes = submits
        let body = text.hasSuffix("\n") && submits ? String(text.dropLast()) : text

        if !body.isEmpty {
            body.withCString { ghostty_surface_text(surface, $0, UInt(body.utf8.count)) }
        }

        // Почему: текст уезжает в bracketed paste, шелл его не выполнит без Return
        guard executes else { return }

        sendReturn(surface)
    }

    func sendReturn(_ surface: ghostty_surface_t) {
        var key = ghostty_input_key_s()
        key.keycode = 36
        key.mods = GHOSTTY_MODS_NONE
        key.consumed_mods = GHOSTTY_MODS_NONE
        key.composing = false
        key.unshifted_codepoint = 0
        key.text = nil

        key.action = GHOSTTY_ACTION_PRESS
        _ = ghostty_surface_key(surface, key)
        key.action = GHOSTTY_ACTION_RELEASE
        _ = ghostty_surface_key(surface, key)
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
        guard visibility == .visible else { return }

        // Почему: анимация сайдбара шлёт десятки размеров, а каждый — релейаут и вспышка
        guard inLiveResize || appliedSize == (0, 0) else {
            resizeWork?.cancel()

            let settle = DispatchWorkItem { [weak self] in
                self?.resizeWork = nil
                self?.applyPendingSize()
            }

            resizeWork = settle
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleInterval, execute: settle)

            return
        }

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

private extension Unicode.Scalar {

    var isInsertable: Bool {
        value >= 0x20 && value != 0x7F && !(0xF700...0xF8FF).contains(value)
    }
}
