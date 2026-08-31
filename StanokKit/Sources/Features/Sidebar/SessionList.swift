import AppKit
import SwiftUI

struct SessionList: View {

    let store: SessionStore

    let live: Set<TerminalSession.ID>

    let processUsage: [TerminalSession.ID: ProcessTreeUsage]

    let insertAgentCommand: (AgentResumeAction, TerminalSession.ID?) -> Void

    @Binding
    var selection: TerminalSession.ID?

    @Environment(\.agentSessionRegistry)
    private var agentSessionRegistry

    var body: some View {
        VStack(spacing: 0) {
            if store.sessions.isEmpty {
                emptyState
            } else {
                sessions
            }

            SidebarToolbar()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    private var sessions: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(store.sessions) { session in
                    sessionRow(session)

                    ForEach(agentSessionRegistry.registeredProviders) { provider in
                        agentSessions(provider, for: session)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
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
