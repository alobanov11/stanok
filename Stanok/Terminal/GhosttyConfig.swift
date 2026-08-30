import Foundation
import GhosttyKit

@MainActor
final class GhosttyConfig {

    var diagnostics: [String] {
        let count = ghostty_config_diagnostics_count(handle)
        return (0..<count).compactMap { index in
            let diagnostic = ghostty_config_get_diagnostic(handle, index)
            guard let message = diagnostic.message else { return nil }
            return String(cString: message)
        }
    }

    let handle: ghostty_config_t

    init(handle: ghostty_config_t) {
        self.handle = handle
    }

    func number(_ key: String) -> Double? {
        var value: Double = 0
        guard ghostty_config_get(handle, &value, key, UInt(key.utf8.count)) else { return nil }
        return value
    }

    func text(_ key: String) -> String? {
        var value: UnsafePointer<CChar>?
        guard ghostty_config_get(handle, &value, key, UInt(key.utf8.count)), let value else { return nil }
        return String(cString: value)
    }
}
