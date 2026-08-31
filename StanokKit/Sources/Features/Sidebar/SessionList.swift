import AppKit
import SwiftUI

struct SessionList: View {

    private static let paneIndent: CGFloat = 20
    let store: SessionStore
    let live: Set<TerminalSession.ID>
    let insertAgentCommand: (AgentResumeAction, TerminalSession.ID?) -> Void
    let copyAgentCommand: (AgentResumeAction, TerminalSession.ID?) -> Void
    let closeSession: (TerminalSession) -> Void

    @Binding
    var selection: TerminalSession.ID?

    @State
    private var chatFilter = ""

    @State
    private var dropTarget: TerminalSession.ID?

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
            .mask { listMask }

            SidebarToolbar(filterText: $chatFilter)
        }
    }

    private var listMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 24)

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
            ForEach(Array(store.roots.enumerated()), id: \.element.id) { index, root in
                rootRow(root, at: index)

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

    private func rootRow(_ root: TerminalSession, at index: Int) -> some View {
        sessionRow(root, indent: 0, isDropTarget: dropTarget == root.id)
            .draggable(root.id.uuidString) {
                Text(root.displayName)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .dropDestination(for: String.self) { items, _ in
                move(items, to: index)
            } isTargeted: { isTargeted in
                dropTarget = isTargeted ? root.id : nil
            }
    }

    private func move(_ items: [String], to index: Int) -> Bool {
        guard
            let raw = items.first,
            let id = UUID(uuidString: raw),
            store.roots.contains(where: { $0.id == id })
        else { return false }

        withAnimation(.smooth(duration: 0.22)) { store.moveRoot(id, to: index) }
        return true
    }

    private func sessionRow(
        _ session: TerminalSession,
        indent: CGFloat,
        isDropTarget: Bool = false
    ) -> some View {
        SidebarRow(
            icon: "apple.terminal",
            title: session.displayName,
            isSelected: session.id == selection,
            isMuted: !session.isReachable,
            isLive: live.contains(session.id),
            indent: indent,
            isDropTarget: isDropTarget,
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
