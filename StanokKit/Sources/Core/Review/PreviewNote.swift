import Foundation

// Почему: правка живёт ровно до отправки в терминал, поэтому у неё нет ни хранения, ни статуса
public struct PreviewNote: Sendable, Equatable {

    public let url: URL
    public let line: Int
    public let text: String
    public let code: String?

    public init(url: URL, line: Int, text: String, code: String? = nil) {
        self.url = url
        self.line = line
        self.text = text
        self.code = code
    }

    public func message(relativeTo root: String?) -> String {
        let path = url.path(percentEncoded: false)
        let base = root.map { $0.hasSuffix("/") ? $0 : $0 + "/" }
        let shown = base.flatMap { path.hasPrefix($0) ? String(path.dropFirst($0.count)) : nil }
            ?? url.lastPathComponent

        // Почему: агенту и ревьюеру нужна сама строка, иначе адрес без контекста
        guard let code, !code.isEmpty else { return "\(shown):\(line) — \(text)" }

        return "\(shown):\(line) — \(text)\n    \(code)"
    }
}
