import Foundation
import GhosttyKit

enum GhosttyInfo {
    static var version: String {
        let info = ghostty_info()
        guard let pointer = info.version else { return "unknown" }
        let bytes = UnsafeBufferPointer(start: pointer, count: Int(info.version_len))
        return String(decoding: bytes.map { UInt8(bitPattern: $0) }, as: UTF8.self)
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
