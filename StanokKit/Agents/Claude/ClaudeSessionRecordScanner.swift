import Foundation
import StanokKit

enum ClaudeSessionRecordScanner {

    struct Result: Equatable, Sendable {

        static let empty = Result(
            sessionID: nil,
            title: nil,
            cwd: nil,
            firstUserMessageText: nil
        )

        let sessionID: String?
        let title: String?
        let cwd: String?
        let firstUserMessageText: String?

        func merging(_ next: Result) -> Result {
            Result(
                // Почему: заголовок задаёт последняя запись ai-title, остальные поля — первая
                sessionID: sessionID ?? next.sessionID,
                title: next.title ?? title,
                cwd: cwd ?? next.cwd,
                firstUserMessageText: firstUserMessageText ?? next.firstUserMessageText
            )
        }

        func filling(from other: Result) -> Result {
            Result(
                sessionID: sessionID ?? other.sessionID,
                title: title ?? other.title,
                cwd: cwd ?? other.cwd,
                firstUserMessageText: firstUserMessageText ?? other.firstUserMessageText
            )
        }
    }

    private enum Limits {

        static let maxLineBytes = 64 * 1024
        static let maxTitleLength = 200
    }

    static func scan(_ data: Data) -> Result {
        var result = Result.empty
        var start = data.startIndex

        while start < data.endIndex {
            let newline = data[start...].firstIndex(of: 0x0A) ?? data.endIndex
            let lineLength = data.distance(from: start, to: newline)

            if lineLength > 0, lineLength <= Limits.maxLineBytes {
                result = result.merging(record(from: data[start..<newline]))
            }

            guard newline < data.endIndex else { break }

            start = data.index(after: newline)
        }

        return result
    }

    private static func record(from line: Data) -> Result {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else { return .empty }

        return Result(
            sessionID: object["sessionId"] as? String,
            title: title(from: object),
            cwd: object["cwd"] as? String,
            firstUserMessageText: userMessageText(object).map {
                UntrustedText.sanitizedSingleLine($0, maxLength: Limits.maxTitleLength)
            }
        )
    }

    private static func title(from object: [String: Any]) -> String? {
        guard
            object["type"] as? String == "ai-title",
            let raw = object["aiTitle"] as? String
        else { return nil }

        return UntrustedText.sanitizedSingleLine(raw, maxLength: Limits.maxTitleLength)
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
