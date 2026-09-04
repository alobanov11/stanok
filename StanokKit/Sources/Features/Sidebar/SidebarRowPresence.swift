import SwiftUI

// Почему: в списке нужно различать свёрнутый терминал и тот, что сейчас на экране
enum SidebarRowPresence {

    case idle
    case hidden
    case onScreen

    var icon: String {
        self == .onScreen ? "apple.terminal.fill" : "apple.terminal"
    }

    var style: AnyShapeStyle {
        switch self {
        case .idle: AnyShapeStyle(.secondary)
        case .hidden: AnyShapeStyle(Color.green.opacity(0.45))
        case .onScreen: AnyShapeStyle(Color.green)
        }
    }
}
