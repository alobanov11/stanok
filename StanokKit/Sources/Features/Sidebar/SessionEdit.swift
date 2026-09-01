import Foundation

struct SessionEdit: Identifiable {

    enum Field {

        case title
        case header
    }

    var title: String {
        switch field {
        case .title: "Название терминала"
        case .header: "Заголовок группы"
        }
    }

    var prompt: String {
        switch field {
        case .title: "Как называть терминал"
        case .header: "Что написать над терминалом"
        }
    }

    let id: TerminalSession.ID
    let field: Field
}
