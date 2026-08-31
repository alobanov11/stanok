import Foundation

enum ClaudeServiceSessionsFilter {

    private static var hiddenDirectoryName: String {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude-mem", directoryHint: .isDirectory)
            .appending(path: "observer-sessions", directoryHint: .isDirectory)
        return encode(url.path(percentEncoded: false))
    }

    static func isServiceDirectory(_ directoryName: String) -> Bool {
        directoryName == hiddenDirectoryName
    }

    private static func encode(_ path: String) -> String {
        var trimmed = path
        if trimmed.count > 1, trimmed.hasSuffix("/") { trimmed.removeLast() }

        var result = ""
        result.reserveCapacity(trimmed.count)
        for character in trimmed {
            switch character {
            case "/", "_", ".":
                result.append("-")
            default:
                result.append(character)
            }
        }
        return result
    }
}
