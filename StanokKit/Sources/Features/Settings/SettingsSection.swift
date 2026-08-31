import Foundation

public enum SettingsSection: String, CaseIterable, Identifiable, Hashable {

    case terminal

    case preview

    case agents

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .terminal: "Терминал"
        case .preview: "Просмотр"
        case .agents: "Чаты агентов"
        }
    }

    public var icon: String {
        switch self {
        case .terminal: "terminal"
        case .preview: "doc.text.magnifyingglass"
        case .agents: "bubble.left.and.text.bubble.right"
        }
    }
}
