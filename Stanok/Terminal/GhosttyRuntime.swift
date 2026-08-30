import AppKit
import Foundation
import GhosttyKit
import os

@MainActor
@Observable
final class GhosttyRuntime {

    enum Failure: Error {

        case initialization(Int32)
        case configuration
        case application
    }

    @ObservationIgnored
    static var currentSurface: ghostty_surface_t?

    @ObservationIgnored
    private(set) weak static var current: GhosttyRuntime?

    @ObservationIgnored
    static var configURL: URL {
        let root = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].flatMap {
            $0.hasPrefix("/") ? URL(filePath: $0, directoryHint: .isDirectory) : nil
        } ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config", directoryHint: .isDirectory)
        return root.appending(path: "stanok", directoryHint: .isDirectory)
            .appending(path: "config.ghostty", directoryHint: .notDirectory)
    }

    private(set) var config: GhosttyConfig

    @ObservationIgnored
    let app: ghostty_app_t

    init() throws {
        let status = ghostty_init(0, nil)
        guard status == 0 else { throw Failure.initialization(status) }

        guard let handle = ghostty_config_new() else { throw Failure.configuration }
        ghostty_config_load_default_files(handle)
        ghostty_config_load_recursive_files(handle)

        let ownConfig = Self.configURL
        if FileManager.default.fileExists(atPath: ownConfig.path(percentEncoded: false)) {
            ownConfig.path(percentEncoded: false).withCString { ghostty_config_load_file(handle, $0) }
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
        runtime.action_cb = { _, _, _ in false }
        runtime.read_clipboard_cb = { _, kind, state in
            let contents = MainActor.assumeIsolated {
                NSPasteboard.general.string(forType: .string)
            }
            guard let contents, let surface = GhosttyRuntime.currentSurface else { return false }
            _ = kind
            contents.withCString { pointer in
                ghostty_surface_complete_clipboard_request(surface, pointer, state, true)
            }
            return true
        }
        runtime.confirm_read_clipboard_cb = { _, _, _, _ in }
        runtime.write_clipboard_cb = { _, _, contents, count, _ in
            guard let contents, count > 0 else { return }
            let items = UnsafeBufferPointer(start: contents, count: count)
            let text = items.compactMap { $0.data.map { String(cString: $0) } }.joined()
            guard !text.isEmpty else { return }
            MainActor.assumeIsolated {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        runtime.close_surface_cb = { _, _ in }

        guard let app = ghostty_app_new(&runtime, handle) else { throw Failure.application }
        self.app = app

        Self.current = self
    }

    func tick() {
        ghostty_app_tick(app)
    }
}
