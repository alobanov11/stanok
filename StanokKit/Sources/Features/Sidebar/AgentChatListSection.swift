import SwiftUI

struct AgentChatListSection: View {

    private var state: AgentSessionsLoadState {
        registry.allSessions(providerID: providerID)
    }

    var body: some View {
        VStack(spacing: 2) {
            SectionHeader(title: title)

            content
        }
        .onAppear { registry.observeAllSessions(providerID: providerID) }
    }

    let providerID: String
    let title: String
    let filter: String
    let onCopy: (AgentSession) -> Void
    let onInsert: (AgentSession) -> Void

    @Environment(\.agentSessionRegistry)
    private var registry

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            statusRow("Загрузка чатов…")

        case let .loaded(sessions) where sessions.isEmpty:
            statusRow("Чатов не найдено")

        case let .loaded(sessions):
            filteredContent(sessions)

        case .failed:
            statusRow("Не удалось загрузить чаты")
        }
    }

    @ViewBuilder
    private func filteredContent(_ sessions: [AgentSession]) -> some View {
        let filtered = AgentSessionFilter.apply(filter, to: sessions)

        if filtered.isEmpty {
            statusRow("Ничего не найдено")
        } else {
            ForEach(filtered) { session in
                AgentChatRow(session: session)
                    .onTapGesture(count: 2) { onInsert(session) }
                    .onTapGesture { onCopy(session) }
            }
        }
    }

    private func statusRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
