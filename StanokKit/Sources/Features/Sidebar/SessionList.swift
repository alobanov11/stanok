import AppKit
import SwiftUI

struct SessionList: View {

    private enum Fade {

        static let top: CGFloat = 24
        static let bottom: CGFloat = 28
    }

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

    @State
    private var edit: SessionEdit?

    @State
    private var editText = ""

    @State
    private var above: CGFloat = 0

    @State
    private var below: CGFloat = 0

    @Environment(\.agentSessionRegistry)
    private var agentSessionRegistry

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 2) {
                    shells

                    chats
                }
                .padding(.horizontal, 8)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                above = min(max(offset, 0), Fade.top)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height
                    - geometry.contentOffset.y
                    - geometry.containerSize.height
                    + geometry.contentInsets.bottom
            } action: { _, offset in
                below = min(max(offset, 0), Fade.bottom)
            }
            .mask { listMask }

            SidebarToolbar(filterText: $chatFilter)
        }
        // Почему: секция чатов ленивая и может не всплыть, а грузить их надо с самого начала
        .task(id: agentSessionRegistry.registeredProviders.map(\.id)) {
            for provider in agentSessionRegistry.registeredProviders {
                agentSessionRegistry.observeAllSessions(providerID: provider.id)
            }
        }
        .alert(edit?.title ?? "", isPresented: isEditing, presenting: edit) { pending in
            TextField(pending.prompt, text: $editText)

            Button("Сохранить") { apply(pending) }

            Button("Отмена", role: .cancel) {}
        }
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { edit != nil }, set: { if !$0 { edit = nil } })
    }

    private var listMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: above)

            Color.black

            LinearGradient(
                colors: [.black, .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: below)
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
                if let header = root.header, !header.isEmpty {
                    SectionHeader(title: header)
                }

                rootRow(root, at: index)

                ForEach(store.panes(of: root).filter { $0.id != root.id }) { pane in
                    sessionRow(pane, indent: SessionList.paneIndent)
                }
            }
        }
    }

    private var chats: some View {
        ForEach(agentSessionRegistry.registeredProviders) { provider in
            ChatListSection(
                providerID: provider.id,
                title: provider.displayName,
                filter: chatFilter,
                onCopy: copyAgentChat,
                onInsert: resumeAgentChat
            )
        }
    }
}

private extension SessionList {

    func copyAgentChat(_ session: AgentSession) {
        copyAgentCommand(session.resumeAction, selection)
    }

    func resumeAgentChat(_ session: AgentSession) {
        guard let folder = session.folder else { return }

        let key = session.id.sessionID
        // Почему: повторный клик по чату переиспользует его терминал, а не плодит новые
        if let opened = store.sessions.first(where: { $0.agent == key }) {
            selection = opened.id
            return
        }

        let target = store.addSession(url: folder, agent: key).id
        selection = target
        insertAgentCommand(session.resumeAction, target)
    }

    func rootRow(_ root: TerminalSession, at index: Int) -> some View {
        sessionRow(root, indent: 0, isRoot: true, isDropTarget: dropTarget == root.id)
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

    func move(_ items: [String], to index: Int) -> Bool {
        guard
            let raw = items.first,
            let id = UUID(uuidString: raw),
            store.roots.contains(where: { $0.id == id })
        else { return false }

        withAnimation(.smooth(duration: 0.22)) { store.moveRoot(id, to: index) }
        return true
    }

    func sessionRow(
        _ session: TerminalSession,
        indent: CGFloat,
        isRoot: Bool = false,
        isDropTarget: Bool = false
    ) -> some View {
        SidebarRow(
            icon: "apple.terminal",
            title: session.displayName,
            isSelected: session.id == selection,
            isMuted: store.unreachable.contains(session.id),
            isLive: live.contains(session.id),
            indent: indent,
            isDropTarget: isDropTarget,
            close: { closeSession(session) }
        )
        .onTapGesture { selection = session.id }
        .contextMenu {
            Button("Переименовать…") { startEditing(session, field: .title) }

            if session.title != nil {
                Button("Вернуть имя из терминала") { store.setTitle(nil, for: session.id) }
            }

            if isRoot {
                Divider()

                Button(session.header == nil ? "Заголовок сверху…" : "Изменить заголовок…") {
                    startEditing(session, field: .header)
                }

                if session.header != nil {
                    Button("Убрать заголовок") { store.setHeader(nil, for: session.id) }
                }
            }

            Divider()

            Button("Открыть в Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([session.url])
            }
            Button("Новый терминал здесь") {
                withAnimation(.smooth(duration: 0.22)) { addSession(at: session.url) }
            }
            Button("Закрыть терминал", role: .destructive) { closeSession(session) }
        }
    }

    func addSession(at url: URL) {
        selection = store.addSession(url: url).id
    }

    func startEditing(_ session: TerminalSession, field: SessionEdit.Field) {
        editText = field == .title ? (session.title ?? "") : (session.header ?? "")
        edit = SessionEdit(id: session.id, field: field)
    }

    func apply(_ pending: SessionEdit) {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch pending.field {
        case .title: store.setTitle(text.isEmpty ? nil : text, for: pending.id)
        case .header: withAnimation(.smooth(duration: 0.2)) {
                store.setHeader(text.isEmpty ? nil : text, for: pending.id)
            }
        }
    }
}
