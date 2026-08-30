import Foundation

public enum SettingsSection: String, CaseIterable, Identifiable, Hashable {

    case terminal
    case preview

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .terminal: "Терминал"
        case .preview: "Просмотр"
        }
    }

    public var icon: String {
        switch self {
        case .terminal: "terminal"
        case .preview: "doc.text.magnifyingglass"
        }
    }
}
