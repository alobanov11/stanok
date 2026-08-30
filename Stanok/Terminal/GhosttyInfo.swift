import Foundation
import GhosttyKit

enum GhosttyInfo {

    static var version: String {
        let info = ghostty_info()
        guard let pointer = info.version else { return "unknown" }
        let data = Data(bytes: pointer, count: Int(info.version_len))
        return String(data: data, encoding: .utf8) ?? "unknown"
    }

    static var buildMode: String {
        switch ghostty_info().build_mode {
        case GHOSTTY_BUILD_MODE_DEBUG: "debug"
        case GHOSTTY_BUILD_MODE_RELEASE_SAFE: "release-safe"
        case GHOSTTY_BUILD_MODE_RELEASE_FAST: "release-fast"
        case GHOSTTY_BUILD_MODE_RELEASE_SMALL: "release-small"
        default: "unknown"
        }
    }
}
