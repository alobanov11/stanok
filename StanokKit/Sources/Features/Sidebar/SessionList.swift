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

                ForEach(agentSessionRegistry.registeredProviders) { provider in
                    agentSessions(provider, for: session)
                }
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
        guard let folder = session.folder else { return }

        insertAgentCommand(session.resumeAction, store.addSession(url: folder).id)
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

    private func agentSessions(
        _ provider: AgentSessionRegistry.ProviderInfo,
        for session: TerminalSession
    ) -> some View {
        AgentSessionsSection(
            projectURL: session.url,
            providerID: provider.id,
            indent: 20,
            onSelect: { agentSession in insertAgentCommand(agentSession.resumeAction, session.id) }
        )
    }

    private func closeSession(_ session: TerminalSession) {
        if selection == session.id { selection = nil }

        withAnimation(.smooth(duration: 0.22)) { store.removeSession(session.id) }
    }

    private func addSession(at url: URL) {
        selection = store.addSession(url: url).id
    }
}
