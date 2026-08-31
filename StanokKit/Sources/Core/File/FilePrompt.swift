import Foundation

struct FilePrompt: Identifiable {

    enum Kind {

        case newFile
        case newFolder
        case rename
    }

    var title: String {
        switch kind {
        case .newFile: "Новый файл"
        case .newFolder: "Новая папка"
        case .rename: "Переименовать"
        }
    }

    let id = UUID()
    let kind: Kind
    let target: URL
}
