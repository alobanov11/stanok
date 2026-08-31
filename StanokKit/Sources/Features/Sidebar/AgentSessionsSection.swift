import SwiftUI

struct AgentSessionsSection: View {

    private var state: AgentSessionsLoadState { registry.sessions(for: projectURL) }

    var body: some View {
        Group {
            switch state {
            case .loading:
                statusRow("Загрузка чатов…")

            case let .loaded(sessions) where sessions.isEmpty:
                statusRow("Чатов не найдено")

            case let .loaded(sessions):
                ForEach(sessions) { session in
                    AgentSessionRow(session: session, indent: indent)
                        .onTapGesture { onSelect(session) }
                }

            case .failed:
                statusRow("Не удалось загрузить чаты")
            }
        }
        .onAppear { registry.observe(projectURL) }
    }

    let projectURL: URL

    let indent: CGFloat

    let onSelect: (AgentSession) -> Void

    @Environment(\.agentSessionRegistry)
    private var registry

    private func statusRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.leading, 8 + indent)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
