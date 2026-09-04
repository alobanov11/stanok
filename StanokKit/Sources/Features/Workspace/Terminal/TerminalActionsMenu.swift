import SwiftUI

struct TerminalActionsMenu: View {

    var body: some View {
        HStack(spacing: 2) {
            if let drag {
                // Почему: перетаскивание живёт на явной ручке, иначе оно спорит с выделением текста
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 20)
                    .contentShape(.capsule)
                    .help("Перетащить терминал")
                    .onDrag(drag)
            }

            menu
        }
    }

    private var menu: some View {
        Menu {
            Button("Новый терминал", action: newTerminal)

            Button("Скрыть", action: hide)

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

    let hide: () -> Void
    let newTerminal: () -> Void
    let close: () -> Void

    var drag: (() -> NSItemProvider)?
}
