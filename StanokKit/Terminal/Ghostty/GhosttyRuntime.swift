import AppKit
import Foundation
import GhosttyKit
import os
import StanokKit

@MainActor
@Observable
public final class GhosttyRuntime {

    enum Failure: Error {

        case initialization(Int32)
        case configuration
        case application
    }

    final class WakeupContext {

        weak var runtime: GhosttyRuntime?
    }

    @ObservationIgnored
    private static var isInitialized = false

    @ObservationIgnored
    private static var isAsking = false

    private(set) var config: GhosttyConfig

    @ObservationIgnored
    nonisolated(unsafe) let app: ghostty_app_t

    @ObservationIgnored
    private let wakeupContext = WakeupContext()

    public init() throws {
        try Self.initializeOnce()

        guard let handle = Self.loadConfig() else { throw Failure.configuration }

        let config = GhosttyConfig(handle: handle)
        if !config.diagnostics.isEmpty {
            Log.terminal.error(
                "config diagnostics: \(config.diagnostics.joined(separator: "; "))"
            )
        }
        self.config = config

        var runtime = ghostty_runtime_config_s()
        runtime.userdata = Unmanaged.passUnretained(wakeupContext).toOpaque()
        runtime.supports_selection_clipboard = false
        runtime.wakeup_cb = { userdata in
            GhosttyRuntime.handleWakeup(userdata)
        }
        runtime.action_cb = { _, target, action in
            guard target.tag == GHOSTTY_TARGET_SURFACE else { return false }

            switch action.tag {
            case GHOSTTY_ACTION_COMMAND_FINISHED:
                let finished = action.action.command_finished
                GhosttyRuntime.assertMainThread()
                return MainActor.assumeIsolated {
                    guard
                        let surface = target.target.surface,
                        let view = GhosttySurfaceView.from(surface: surface)
                    else { return false }

                    view.onCommandFinished?(
                        CommandRun(
                            exitCode: finished.exit_code,
                            durationNanoseconds: finished.duration
                        )
                    )
                    return true
                }

            case GHOSTTY_ACTION_OPEN_URL:
                let openURL = action.action.open_url
                guard let pointer = openURL.url else { return false }

                let link = String(
                    decoding: UnsafeRawBufferPointer(start: pointer, count: Int(openURL.len)),
                    as: UTF8.self
                )
                GhosttyRuntime.assertMainThread()
                return MainActor.assumeIsolated {
                    guard
                        let surface = target.target.surface,
                        let view = GhosttySurfaceView.from(surface: surface)
                    else { return false }

                    view.onOpenURL?(link)
                    return true
                }

            case GHOSTTY_ACTION_SET_TITLE:
                return GhosttyRuntime.handleSetTitle(action.action.set_title, target: target)

            case GHOSTTY_ACTION_PWD:
                return GhosttyRuntime.handlePwd(action.action.pwd, target: target)

            case GHOSTTY_ACTION_SCROLLBAR:
                let scrollbar = action.action.scrollbar
                GhosttyRuntime.assertMainThread()
                return MainActor.assumeIsolated {
                    guard
                        let surface = target.target.surface,
                        let view = GhosttySurfaceView.from(surface: surface)
                    else { return false }

                    view.updateScrollbar(
                        TerminalScrollbar(
                            total: scrollbar.total,
                            offset: scrollbar.offset,
                            length: scrollbar.len
                        )
                    )
                    return true
                }

            case GHOSTTY_ACTION_MOUSE_SHAPE:
                let shape = action.action.mouse_shape
                GhosttyRuntime.assertMainThread()
                return MainActor.assumeIsolated {
                    guard
                        let surface = target.target.surface,
                        let view = GhosttySurfaceView.from(surface: surface)
                    else { return false }

                    view.setCursorShape(shape)
                    return true
                }

            default:
                return false
            }
        }
        runtime.read_clipboard_cb = { userdata, _, state in
            GhosttyRuntime.assertMainThread()
            return MainActor.assumeIsolated {
                guard
                    let text = TerminalPaste.text(),
                    let surface = GhosttySurfaceView.from(userdata: userdata)?.handle
                else { return false }

                text.withCString { pointer in
                    ghostty_surface_complete_clipboard_request(surface, pointer, state, false)
                }
                return true
            }
        }
        runtime.confirm_read_clipboard_cb = { userdata, text, state, request in
            let pending = text.map { String(cString: $0) } ?? ""
            GhosttyRuntime.assertMainThread()
            MainActor.assumeIsolated {
                GhosttyRuntime.confirmClipboard(
                    userdata: userdata,
                    text: pending,
                    state: state,
                    request: request
                )
            }
        }
        runtime.write_clipboard_cb = { userdata, _, contents, count, confirm in
            guard confirm else {
                GhosttyRuntime.writeClipboard(contents, count: count)
                return
            }

            GhosttyRuntime.assertMainThread()
            MainActor.assumeIsolated {
                GhosttyRuntime.confirmWrite(userdata: userdata, contents: contents, count: count)
            }
        }
        runtime.close_surface_cb = { userdata, processAlive in
            GhosttyRuntime.handleCloseSurface(userdata: userdata, processAlive: processAlive)
        }

        guard let app = ghostty_app_new(&runtime, handle) else { throw Failure.application }
        self.app = app

        wakeupContext.runtime = self
    }

    deinit {
        ghostty_app_free(app)
    }

    static func loadConfig() -> ghostty_config_t? {
        guard let handle = ghostty_config_new() else { return nil }

        ghostty_config_load_default_files(handle)

        let own = AppPaths.ghosttyConfig
        if FileManager.default.fileExists(atPath: own.path(percentEncoded: false)) {
            own.path(percentEncoded: false).withCString { ghostty_config_load_file(handle, $0) }
        }

        ghostty_config_load_recursive_files(handle)
        ghostty_config_finalize(handle)
        return handle
    }

    static func initializeOnce() throws {
        guard !isInitialized else { return }

        let status = ghostty_init(0, nil)
        guard status == 0 else { throw Failure.initialization(status) }

        isInitialized = true
    }

    private nonisolated static func assertMainThread() {
        assert(Thread.isMainThread, "ghostty runtime callback fired off the main thread")
    }

    public func reloadConfig() {
        guard let handle = Self.loadConfig() else {
            Log.terminal.error("config reload failed: could not load config")
            return
        }

        let candidate = GhosttyConfig(handle: handle)
        guard candidate.diagnostics.isEmpty else {
            Log.terminal.error(
                "config reload rejected: \(candidate.diagnostics.joined(separator: "; "))"
            )
            return
        }

        ghostty_app_update_config(app, handle)
        config = candidate
        Log.terminal.info("config reloaded")
    }

    func tick() {
        ghostty_app_tick(app)
    }
}

private extension GhosttyRuntime {

    static func confirmClipboard(
        userdata: UnsafeMutableRawPointer?,
        text: String,
        state: UnsafeMutableRawPointer?,
        request: ghostty_clipboard_request_e
    ) {
        guard let view = GhosttySurfaceView.from(userdata: userdata) else { return }

        guard !isAsking else {
            answer("", to: view.handle, state: state)
            return
        }

        isAsking = true

        let question = message(for: request)
        DispatchQueue.main.async { [weak view] in
            let allowed = ask(question, detail: preview(of: text))
            isAsking = false

            answer(allowed ? text : "", to: view?.handle, state: state)
        }
    }

    static func answer(
        _ text: String,
        to surface: ghostty_surface_t?,
        state: UnsafeMutableRawPointer?
    ) {
        guard let surface else { return }

        text.withCString { pointer in
            ghostty_surface_complete_clipboard_request(surface, pointer, state, true)
        }
    }

    static func confirmWrite(
        userdata: UnsafeMutableRawPointer?,
        contents: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int
    ) {
        guard let copies = copied(contents, count: count) else { return }

        DispatchQueue.main.async {
            let joined = copies.map(\.data).joined()
            guard
                ask(
                    message(for: GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE),
                    detail: preview(of: joined)
                )
            else { return }

            writeFlavors(copies)
        }
    }

    static func ask(_ question: String, detail: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Разрешить")
        alert.addButton(withTitle: "Отмена")

        return alert.runModal() == .alertFirstButtonReturn
    }

    static func message(for request: ghostty_clipboard_request_e) -> String {
        switch request {
        case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ:
            "Программа в терминале хочет прочитать буфер обмена"

        case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE:
            "Программа в терминале хочет записать в буфер обмена"

        default:
            "Вставить содержимое буфера обмена?"
        }
    }

    static func preview(of text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: "⏎ ")
        guard flat.count > 200 else { return flat }

        return String(flat.prefix(200)) + "…"
    }

    static func handleWakeup(_ userdata: UnsafeMutableRawPointer?) {
        guard let userdata else { return }

        let context = Unmanaged<WakeupContext>.fromOpaque(userdata).takeUnretainedValue()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                context.runtime?.tick()
            }
        }
    }

    static func handleSetTitle(
        _ setTitle: ghostty_action_set_title_s,
        target: ghostty_target_s
    ) -> Bool {
        guard let pointer = setTitle.title else { return false }

        let title = UntrustedText.sanitizedSingleLine(String(cString: pointer), maxLength: 60)
        GhosttyRuntime.assertMainThread()
        return MainActor.assumeIsolated {
            guard
                let surface = target.target.surface,
                let view = GhosttySurfaceView.from(surface: surface)
            else { return false }

            view.onTitleChanged?(title)
            return true
        }
    }

    static func handlePwd(
        _ pwd: ghostty_action_pwd_s,
        target: ghostty_target_s
    ) -> Bool {
        guard let pointer = pwd.pwd else { return false }

        let path = String(cString: pointer)
        GhosttyRuntime.assertMainThread()
        return MainActor.assumeIsolated {
            guard
                let surface = target.target.surface,
                let view = GhosttySurfaceView.from(surface: surface)
            else { return false }

            view.onPwdChanged?(path)
            return true
        }
    }

    static func handleCloseSurface(userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
        GhosttyRuntime.assertMainThread()
        MainActor.assumeIsolated {
            guard let view = GhosttySurfaceView.from(userdata: userdata) else { return }

            guard let onCloseRequested = view.onCloseRequested else {
                Log.terminal.error("ghostty requested to close a surface with no handler")
                return
            }
            onCloseRequested(processAlive)
        }
    }

    static func writeClipboard(
        _ contents: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int
    ) {
        guard let items = copied(contents, count: count) else { return }

        GhosttyRuntime.assertMainThread()
        MainActor.assumeIsolated { writeFlavors(items) }
    }

    static func copied(
        _ contents: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int
    ) -> [(mime: String, data: String)]? {
        guard let contents, count > 0 else { return nil }

        let items = UnsafeBufferPointer(start: contents, count: count).compactMap { item in
            item.data.map { data in
                (mime: item.mime.map { String(cString: $0) } ?? "", data: String(cString: data))
            }
        }

        return items.isEmpty ? nil : items
    }

    static func writeFlavors(_ items: [(mime: String, data: String)]) {
        var flavors: [NSPasteboard.PasteboardType: String] = [:]
        for item in items {
            switch item.mime.isEmpty ? "text/plain" : item.mime {
            case "text/html": flavors[.html] = item.data
            case "text/plain": flavors[.string] = item.data
            default: continue
            }
        }
        guard !flavors.isEmpty else { return }

        NSPasteboard.general.clearContents()
        for (type, value) in flavors {
            NSPasteboard.general.setString(value, forType: type)
        }
    }
}
