import AppKit
import SwiftUI

struct SessionList: View {

    let store: SessionStore

    let live: Set<TerminalSession.ID>

    let processUsage: [TerminalSession.ID: ProcessTreeUsage]

    let insertAgentCommand: (AgentResumeAction, TerminalSession.ID?) -> Void

    @Binding
    var selection: TerminalSession.ID?

    @State
    private var chatFilter = ""

    @Environment(\.agentSessionRegistry)
    private var agentSessionRegistry

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    shells

                    chats
                }
                .padding(.horizontal, 8)
            }

            SidebarToolbar(filterText: $chatFilter)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Нет открытых терминалов")

            Text("⌘N — новый")
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private var shells: some View {
        if store.sessions.isEmpty {
            emptyState
        } else {
            ForEach(store.sessions) { session in
                sessionRow(session)
            }
        }
    }

    private var chats: some View {
        ForEach(agentSessionRegistry.registeredProviders) { provider in
            AgentChatListSection(
                providerID: provider.id,
                title: provider.displayName,
                filter: chatFilter,
                onSelect: resumeAgentChat
            )
        }
    }

    private func resumeAgentChat(_ session: AgentSession) {
        guard let target = selection ?? session.folder.map({ store.addSession(url: $0).id })
        else { return }

        selection = target
        insertAgentCommand(session.resumeAction, target)
    }

    private func sessionRow(_ session: TerminalSession) -> some View {
        SidebarRow(
            icon: "apple.terminal",
            title: session.displayName,
            isSelected: session.id == selection,
            isMuted: !session.isReachable,
            isLive: live.contains(session.id),
            indent: 0,
            close: { closeSession(session) }
        )
        .onTapGesture { selection = session.id }
        .contextMenu {
            Button("Открыть в Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([session.url])
            }
            Button("Новый терминал здесь") {
                withAnimation(.smooth(duration: 0.22)) { addSession(at: session.url) }
            }
            Button("Закрыть терминал", role: .destructive) { closeSession(session) }
        }
    }

    private func closeSession(_ session: TerminalSession) {
        if selection == session.id { selection = neighbour(of: session.id)?.id }

        withAnimation(.smooth(duration: 0.22)) { store.removeSession(session.id) }
    }

    private func neighbour(of sessionID: TerminalSession.ID) -> TerminalSession? {
        guard let index = store.sessions.firstIndex(where: { $0.id == sessionID })
        else { return nil }

        let after = store.sessions[store.sessions.index(after: index)...].first

        return after ?? store.sessions[..<index].last
    }

    private func addSession(at url: URL) {
        selection = store.addSession(url: url).id
    }
}
