import Foundation
import StanokKit

enum ClaudeSessionRecordScanner {

    struct Result: Equatable, Sendable {

        let sessionID: String?

        let title: String?
    }

    private enum Limits {

        static let maxLineBytes = 64 * 1024

        static let maxTitleLength = 200
    }

    static func scan(_ data: Data) -> Result {
        var sessionID: String?
        var title: String?
        var start = data.startIndex

        while start < data.endIndex {
            let newline = data[start...].firstIndex(of: 0x0A) ?? data.endIndex
            let lineLength = data.distance(from: start, to: newline)

            if lineLength > 0, lineLength <= Limits.maxLineBytes {
                let line = data[start..<newline]
                if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                    if sessionID == nil, let id = object["sessionId"] as? String {
                        sessionID = id
                    }
                    if
                        object["type"] as? String == "ai-title",
                        let raw = object["aiTitle"] as? String {
                        title = UntrustedText.sanitizedSingleLine(
                            raw,
                            maxLength: Limits.maxTitleLength
                        )
                    }
                }
            }

            guard newline < data.endIndex else { break }

            start = data.index(after: newline)
        }

        return Result(sessionID: sessionID, title: title)
    }
}
