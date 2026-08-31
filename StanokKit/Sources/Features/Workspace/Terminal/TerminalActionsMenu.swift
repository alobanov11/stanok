import SwiftUI

struct TerminalActionsMenu: View {

    var body: some View {
        Menu {
            Menu("Добавить") {
                Button("Снизу") { split(.bottom) }

                Button("Справа") { split(.trailing) }

                Button("Слева") { split(.leading) }

                Button("Сверху") { split(.top) }
            }

            Button("Новый терминал", action: newTerminal)

            Button("Закрыть", role: .destructive, action: close)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 20)
                .contentShape(.capsule)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Действия с терминалом")
    }

    let split: (SplitDirection) -> Void
    let newTerminal: () -> Void
    let close: () -> Void
}
