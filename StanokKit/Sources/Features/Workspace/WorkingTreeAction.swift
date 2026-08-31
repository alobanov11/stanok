import Foundation

enum WorkingTreeAction: Identifiable {

    case stash

    case discard

    var id: Self { self }

    var command: String {
        switch self {
        case .stash: "git stash push -u"
        case .discard: "git restore . && git clean -fd"
        }
    }

    var title: String {
        "Выполнить \(command)?"
    }

    var message: String {
        switch self {
        case .stash:
            "Изменения и новые файлы уедут в заначку, рабочее дерево станет чистым."
                + " Вернуть — git stash pop."

        case .discard:
            "Правки, удаления и новые файлы, ещё не добавленные в git,"
                + " пропадут безвозвратно. Файлы из .gitignore останутся."
        }
    }

    var isDestructive: Bool {
        self == .discard
    }
}
