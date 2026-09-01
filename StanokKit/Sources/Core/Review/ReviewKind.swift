import Foundation

public enum ReviewKind: String, Sendable, Equatable {

    case git
    case agents

    public var title: String {
        switch self {
        case .git: "Изменения"
        case .agents: "Изменения агентов"
        }
    }
}
