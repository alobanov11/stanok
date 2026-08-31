import Foundation

enum WorkingTreeAction: Identifiable {

    case stash
    case discard

    var id: Self { self }

    var title: String {
        switch self {
        case .stash: "Отложить изменения в заначку?"
        case .discard: "Сбросить все изменения?"
        }
    }

    var message: String {
        switch self {
        case .stash:
            "Рабочее дерево станет чистым. Вернуть отложенное можно командой git stash pop."

        case .discard:
            "Правки и удаления в отслеживаемых файлах пропадут безвозвратно."
        }
    }

    var confirmLabel: String {
        switch self {
        case .stash: "Отложить"
        case .discard: "Сбросить"
        }
    }

    var isDestructive: Bool {
        self == .discard
    }
}
