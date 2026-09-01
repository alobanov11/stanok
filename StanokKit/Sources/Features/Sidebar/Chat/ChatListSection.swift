import SwiftUI

struct ChatListSection: View {

    private var state: AgentSessionsLoadState {
        registry.allSessions(providerID: providerID)
    }

    var body: some View {
        // Почему: Group вместо VStack, чтобы строки попали прямо в ленивый список сайдбара
        Group {
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

    @State
    private var days: [AgentSessionDay]?

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
        Group {
            if let days {
                if days.isEmpty {
                    statusRow("Ничего не найдено")
                } else {
                    ForEach(days) { day in
                        ChatDayHeader(title: day.title)

                        ForEach(day.sessions) { session in
                            ChatRow(session: session)
                                .gesture(
                                    TapGesture(count: 2).onEnded { onInsert(session) }
                                        .exclusively(before: TapGesture().onEnded { onCopy(session) })
                                )
                        }
                    }
                }
            } else {
                statusRow("Загрузка чатов…")
            }
        }
        .task(id: Self.stamp(sessions, filter: filter)) {
            days = AgentSessionGrouping.byDay(AgentSessionFilter.apply(filter, to: sessions))
        }
    }

    private static func stamp(_ sessions: [AgentSession], filter: String) -> String {
        let newest = sessions.max { $0.lastActivityAt < $1.lastActivityAt }?.lastActivityAt

        return "\(sessions.count)|\(newest?.timeIntervalSince1970 ?? 0)|\(filter)"
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
