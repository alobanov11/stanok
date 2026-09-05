import Foundation

public struct TerminalInsertRequest: Equatable, Sendable {

    public let id: UUID
    public let text: String

    // Почему: перевод строки внутри вставки безопасен, а вот Return уже выполняет команду
    public let submits: Bool

    public init(id: UUID = UUID(), text: String, submits: Bool = false) {
        self.id = id
        self.text = text
        self.submits = submits
    }
}
