import SwiftUI

struct SidebarToggle: View {

    var body: some View {
        HStack(spacing: 0) {
            if let addTerminal {
                button("plus", hint: "Новый терминал", action: addTerminal)
            }

            button("sidebar.leading", hint: "Показать/скрыть боковую панель", action: toggle)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    let toggle: () -> Void
    let addTerminal: (() -> Void)?

    private func button(
        _ icon: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: WorkspaceLayout.toggleWidth, height: WorkspaceLayout.toggleHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(hint)
    }
}
