import AppKit
import SwiftUI

struct SessionList: View {

    private static let paneIndent: CGFloat = 20

    let store: SessionStore

    let live: Set<TerminalSession.ID>

    let processUsage: [TerminalSession.ID: ProcessTreeUsage]

    let insertAgentCommand: (AgentResumeAction, TerminalSession.ID?) -> Void

    let copyAgentCommand: (AgentResumeAction, TerminalSession.ID?) -> Void

    let closeSession: (TerminalSession) -> Void

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
            .mask { bottomFade }

            SidebarToolbar(filterText: $chatFilter)
        }
    }

    private var bottomFade: some View {
        VStack(spacing: 0) {
            Color.black

            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
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
        if store.roots.isEmpty {
            emptyState
        } else {
            ForEach(store.roots) { root in
                sessionRow(root, indent: 0)

                ForEach(store.panes(of: root).filter { $0.id != root.id }) { pane in
                    sessionRow(pane, indent: SessionList.paneIndent)
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
                onCopy: copyAgentChat,
                onInsert: resumeAgentChat
            )
        }
    }

    private func copyAgentChat(_ session: AgentSession) {
        copyAgentCommand(session.resumeAction, selection)
    }

    private func resumeAgentChat(_ session: AgentSession) {
        guard let folder = session.folder else { return }

        let target = store.addSession(url: folder).id
        selection = target
        insertAgentCommand(session.resumeAction, target)
    }

    private func sessionRow(_ session: TerminalSession, indent: CGFloat) -> some View {
        SidebarRow(
            icon: "apple.terminal",
            title: session.displayName,
            isSelected: session.id == selection,
            isMuted: !session.isReachable,
            isLive: live.contains(session.id),
            indent: indent,
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

    private func addSession(at url: URL) {
        selection = store.addSession(url: url).id
    }
}
