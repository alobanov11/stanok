import Foundation
import GhosttyKit

@MainActor
@Observable
final class GhosttyRuntime {

    enum Failure: Error {

        case initialization(Int32)
        case configuration
        case application
    }

    private(set) var config: GhosttyConfig

    @ObservationIgnored
    private let app: ghostty_app_t

    init() throws {
        let status = ghostty_init(0, nil)
        guard status == 0 else { throw Failure.initialization(status) }

        guard let handle = ghostty_config_new() else { throw Failure.configuration }
        ghostty_config_load_default_files(handle)
        ghostty_config_load_recursive_files(handle)
        ghostty_config_finalize(handle)
        self.config = GhosttyConfig(handle: handle)

        var runtime = ghostty_runtime_config_s()
        runtime.supports_selection_clipboard = false
        runtime.wakeup_cb = { _ in }
        runtime.action_cb = { _, _, _ in false }
        runtime.read_clipboard_cb = { _, _, _ in false }
        runtime.confirm_read_clipboard_cb = { _, _, _, _ in }
        runtime.write_clipboard_cb = { _, _, _, _, _ in }
        runtime.close_surface_cb = { _, _ in }

        guard let app = ghostty_app_new(&runtime, handle) else { throw Failure.application }
        self.app = app
    }

    func tick() {
        ghostty_app_tick(app)
    }
}
