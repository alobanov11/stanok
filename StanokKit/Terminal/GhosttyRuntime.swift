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

    @ObservationIgnored
    private(set) weak static var current: GhosttyRuntime?

    private(set) var config: GhosttyConfig

    @ObservationIgnored
    let app: ghostty_app_t

    @ObservationIgnored
    private let surfaces = NSHashTable<GhosttySurfaceView>.weakObjects()

    public init() throws {
        let status = ghostty_init(0, nil)
        guard status == 0 else { throw Failure.initialization(status) }

        guard let handle = ghostty_config_new() else { throw Failure.configuration }
        ghostty_config_load_default_files(handle)
        ghostty_config_load_recursive_files(handle)

        let ownConfig = AppPaths.ghosttyConfig
        if FileManager.default.fileExists(atPath: ownConfig.path(percentEncoded: false)) {
            ownConfig.path(percentEncoded: false)
                .withCString { ghostty_config_load_file(handle, $0) }
            Log.terminal.info("loaded \(ownConfig.path(percentEncoded: false))")
        }

        ghostty_config_finalize(handle)
        self.config = GhosttyConfig(handle: handle)

        var runtime = ghostty_runtime_config_s()
        runtime.supports_selection_clipboard = false
        runtime.wakeup_cb = { _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    GhosttyRuntime.current?.tick()
                }
            }
        }
        runtime.action_cb = { _, target, action in
            guard target.tag == GHOSTTY_TARGET_SURFACE else { return false }

            switch action.tag {
            case GHOSTTY_ACTION_COMMAND_FINISHED:
                let finished = action.action.command_finished
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

                let link = String(cString: pointer)
                return MainActor.assumeIsolated {
                    guard
                        let surface = target.target.surface,
                        let view = GhosttySurfaceView.from(surface: surface)
                    else { return false }

                    view.onOpenURL?(link)
                    return true
                }

            default:
                return false
            }
        }
        runtime.read_clipboard_cb = { userdata, _, state in
            MainActor.assumeIsolated {
                guard
                    let text = NSPasteboard.general.string(forType: .string),
                    let surface = GhosttySurfaceView.from(userdata: userdata)?.handle
                else { return false }

                text.withCString { pointer in
                    ghostty_surface_complete_clipboard_request(surface, pointer, state, true)
                }
                return true
            }
        }
        runtime.confirm_read_clipboard_cb = { _, _, _, _ in }
        runtime.write_clipboard_cb = { _, _, contents, count, _ in
            GhosttyRuntime.writeClipboard(contents, count: count)
        }
        runtime.close_surface_cb = { _, _ in }

        guard let app = ghostty_app_new(&runtime, handle) else { throw Failure.application }
        self.app = app

        Self.current = self
    }

    static func loadConfig() -> ghostty_config_t? {
        guard let handle = ghostty_config_new() else { return nil }

        ghostty_config_load_default_files(handle)
        ghostty_config_load_recursive_files(handle)

        let own = AppPaths.ghosttyConfig
        if FileManager.default.fileExists(atPath: own.path(percentEncoded: false)) {
            own.path(percentEncoded: false).withCString { ghostty_config_load_file(handle, $0) }
        }

        ghostty_config_finalize(handle)
        return handle
    }

    private static func writeClipboard(
        _ contents: UnsafePointer<ghostty_clipboard_content_s>?,
        count: Int
    ) {
        guard let contents, count > 0 else { return }

        var flavors: [NSPasteboard.PasteboardType: String] = [:]
        for item in UnsafeBufferPointer(start: contents, count: count) {
            guard let data = item.data else { continue }

            switch item.mime.map({ String(cString: $0) }) ?? "text/plain" {
            case "text/html": flavors[.html] = String(cString: data)
            case "text/plain", "": flavors[.string] = String(cString: data)
            default: continue
            }
        }
        guard !flavors.isEmpty else { return }

        MainActor.assumeIsolated {
            NSPasteboard.general.clearContents()
            for (type, value) in flavors {
                NSPasteboard.general.setString(value, forType: type)
            }
        }
    }

    public func reloadConfig() {
        guard let handle = Self.loadConfig() else { return }

        ghostty_app_update_config(app, handle)
        for view in surfaces.allObjects {
            view.updateConfig(handle)
        }
        config = GhosttyConfig(handle: handle)
        Log.terminal.info("config reloaded")
    }

    func register(_ view: GhosttySurfaceView) {
        surfaces.add(view)
    }

    func tick() {
        ghostty_app_tick(app)
    }
}
