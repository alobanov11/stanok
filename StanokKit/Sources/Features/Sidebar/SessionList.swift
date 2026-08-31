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
            .overlay(alignment: .top) {
                if store.sessions.isEmpty {
                    Text("Нет открытых терминалов")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 60)
                }
            }

            SidebarToolbar()
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
