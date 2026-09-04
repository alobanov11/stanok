import Foundation

@MainActor
@Observable
public final class TerminalSnapshots {

    // Почему: миниатюре хватает последних строк, целый экран держать в памяти незачем
    private enum Limit {

        static let lines = 24
        static let width = 120
        static let sessions = 48
    }

    private var texts: [TerminalSession.ID: String] = [:]
    private var order: [TerminalSession.ID] = []

    public init() {}

    public func text(for session: TerminalSession.ID) -> String? {
        texts[session]
    }

    public func set(_ text: String, for session: TerminalSession.ID) {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .suffix(Limit.lines)
            .map { $0.count > Limit.width ? String($0.prefix(Limit.width)) : String($0) }

        let trimmed = lines.joined(separator: "\n")
        guard texts[session] != trimmed else { return }

        texts[session] = trimmed
        order.removeAll { $0 == session }
        order.append(session)

        while order.count > Limit.sessions, let evicted = order.first {
            texts[evicted] = nil
            order.removeFirst()
        }
    }

    public func forget(_ known: Set<TerminalSession.ID>) {
        texts = texts.filter { known.contains($0.key) }
        order.removeAll { !known.contains($0) }
    }
}
