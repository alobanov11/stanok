import Foundation

enum ClaudeProjectPathEncoder {

    static func encode(_ path: String) -> String {
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
