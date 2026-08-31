import Foundation
import StanokKit

enum ClaudeSessionRecordScanner {

    struct Result: Equatable, Sendable {

        let sessionID: String?

        let title: String?

        let cwd: String?

        let firstTimestamp: Date?

        let firstUserMessageText: String?
    }

    private enum Limits {

        static let maxLineBytes = 64 * 1024

        static let maxTitleLength = 200
    }

    static func scan(_ data: Data) -> Result {
        var sessionID: String?
        var title: String?
        var cwd: String?
        var firstTimestamp: Date?
        var firstUserMessageText: String?
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
                    if cwd == nil, let value = object["cwd"] as? String {
                        cwd = value
                    }
                    if firstTimestamp == nil, let raw = object["timestamp"] as? String {
                        firstTimestamp = parseTimestamp(raw)
                    }
                    if
                        object["type"] as? String == "ai-title",
                        let raw = object["aiTitle"] as? String {
                        title = UntrustedText.sanitizedSingleLine(
                            raw,
                            maxLength: Limits.maxTitleLength
                        )
                    }
                    if firstUserMessageText == nil, let text = userMessageText(object) {
                        firstUserMessageText = UntrustedText.sanitizedSingleLine(
                            text,
                            maxLength: Limits.maxTitleLength
                        )
                    }
                }
            }

            guard newline < data.endIndex else { break }

            start = data.index(after: newline)
        }

        return Result(
            sessionID: sessionID,
            title: title,
            cwd: cwd,
            firstTimestamp: firstTimestamp,
            firstUserMessageText: firstUserMessageText
        )
    }

    private static func parseTimestamp(_ raw: String) -> Date? {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractionalSeconds.date(from: raw) { return date }

        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]
        return withoutFractionalSeconds.date(from: raw)
    }

    private static func userMessageText(_ object: [String: Any]) -> String? {
        guard
            object["type"] as? String == "user",
            object["isSidechain"] as? Bool != true,
            let message = object["message"] as? [String: Any],
            message["role"] as? String == "user"
        else { return nil }

        return textContent(of: message["content"])
    }

    private static func textContent(of content: Any?) -> String? {
        if let text = content as? String { return text }

        guard let blocks = content as? [[String: Any]] else { return nil }

        for block in blocks where block["type"] as? String == "text" {
            if let text = block["text"] as? String { return text }
        }

        return nil
    }
}
