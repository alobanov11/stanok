import Foundation

public enum SettingsSection: String, CaseIterable, Identifiable, Hashable {

    case appearance

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .appearance: "Оформление"
        }
    }

    public var icon: String {
        switch self {
        case .appearance: "paintbrush"
        }
    }
}
