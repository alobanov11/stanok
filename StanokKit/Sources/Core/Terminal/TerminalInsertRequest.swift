import Foundation

public struct TerminalInsertRequest: Equatable, Sendable {

    public let id: UUID
    public let text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}
