import SwiftUI

public struct WorkspaceView<Terminal: View>: View {

    private var insideOffset: CGFloat {
        WorkspaceLayout.inset + WorkspaceLayout.toggleGap
    }

    private var outsideLeading: CGFloat {
        WorkspaceLayout.sidebarWidth - WorkspaceLayout.toggleWidth - WorkspaceLayout.toggleGap
    }

    private var selectedRepository: Repository? {
        selection.flatMap { store.repository(hosting: $0) }
    }

    private var headerLeading: CGFloat {
        guard !isSidebarExpanded else { return 14 }

        return WorkspaceLayout.toggleWidth + WorkspaceLayout.toggleGap * 2
    }

    private var toggleTop: CGFloat {
        WorkspaceLayout.inset + (WorkspaceLayout.headerHeight - WorkspaceLayout.toggleHeight) / 2
    }

    @State
    private var model = WorkspaceModel()

    @State
    private var store = RepositoryStore()

    @State
    private var selection: TerminalSession.ID?

    @State
    private var isSidebarExpanded = true

    @State
    private var isFilesExpanded = false

    @State
    private var live: [TerminalSession.ID] = []

    @State
    private var git = GitStatusStore()

    @State
    private var preview: FilePreview?

    @State
    private var request = UUID()

    public var body: some View {
        HStack(spacing: 0) {
            if isSidebarExpanded {
                sidebar
                    .frame(width: WorkspaceLayout.sidebarWidth)
                    .padding(.top, WorkspaceLayout.sidebarTopInset)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            main
                .padding(.leading, isSidebarExpanded ? 0 : WorkspaceLayout.inset)
                .padding(.trailing, WorkspaceLayout.inset)
                .padding(.vertical, WorkspaceLayout.inset)

            if isFilesExpanded {
                files
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) { toggle }
        .background(TrafficLights(isHidden: !isSidebarExpanded).frame(width: 0, height: 0))
        .ignoresSafeArea()
        .background(WindowBackground().ignoresSafeArea())
        .frame(minWidth: 880, minHeight: 520)
        .task { selectFirstIfNeeded() }
        .task(id: selection) { await git.refresh(selectedRepository) }
        .onChange(of: selection) { _, new in
            guard let new else { return }

            activate(new)
        }
    }

    private var toggle: some View {
        SidebarToggle(action: toggleSidebar)
            .padding(.top, toggleTop)
            .padding(.leading, isSidebarExpanded ? outsideLeading : insideOffset)
    }

    private var files: some View {
        FilePanel(url: selectedRepository?.url, onOpen: open)
            .frame(width: WorkspaceLayout.filesWidth)
            .background { WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius) }
            .clipShape(.rect(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous))
            .padding(.trailing, WorkspaceLayout.inset)
            .padding(.vertical, WorkspaceLayout.inset)
    }

    private var closeButton: some View {
        CloseButton(action: closePreview)
            .padding(.top, (WorkspaceLayout.headerHeight - WorkspaceLayout.toggleHeight) / 2)
            .padding(.trailing, WorkspaceLayout.toggleGap)
    }

    private var sidebar: some View {
        RepositoryTree(store: store, selection: $selection, live: Set(live))
    }

    private var header: some View {
        TerminalHeader(
            repository: selectedRepository,
            status: git.status(for: selectedRepository),
            leadingInset: headerLeading,
            isFilesOpen: isFilesExpanded,
            toggleFiles: toggleFiles
        )
    }

    private var terminals: some View {
        ZStack {
            ForEach(store.repositories) { repository in
                ForEach(repository.sessions) { session in
                    if live.contains(session.id) {
                        terminal(repository, session, isVisible(session)) { model.record($0) }
                            .opacity(isVisible(session) ? 1 : 0)
                            .allowsHitTesting(isVisible(session))
                    }
                }
            }
        }
    }

    private var main: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                terminals
            }

            if let preview {
                previewLayer(preview)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius) }
        .clipShape(.rect(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous))
    }

    private let terminal: (
        Repository,
        TerminalSession,
        Bool,
        @escaping (CommandRun) -> Void
    ) -> Terminal

    public init(
        @ViewBuilder terminal: @escaping (
            Repository,
            TerminalSession,
            Bool,
            @escaping (CommandRun) -> Void
        ) -> Terminal
    ) {
        self.terminal = terminal
    }

    private func previewLayer(_ preview: FilePreview) -> some View {
        PreviewPanel(preview: preview)
            .background {
                WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius)
            }
            .overlay(alignment: .topTrailing) { closeButton }
            .zIndex(1)
            .transition(.opacity)
    }

    private func isVisible(_ session: TerminalSession) -> Bool {
        session.id == selection && preview == nil
    }

    private func open(_ url: URL) {
        let token = UUID()
        request = token

        Task {
            let loaded = await FilePreviewLoader.load(url)
            guard request == token else { return }

            withAnimation(.smooth(duration: 0.18)) { preview = loaded }
        }
    }

    private func closePreview() {
        request = UUID()
        withAnimation(.smooth(duration: 0.18)) { preview = nil }
    }

    private func toggleSidebar() {
        withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) {
            isSidebarExpanded.toggle()
        }
    }

    private func toggleFiles() {
        withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) {
            isFilesExpanded.toggle()
        }
    }

    private func selectFirstIfNeeded() {
        guard selection == nil else { return }

        selection = store.repositories.first?.sessions.first?.id
        if let selection { activate(selection) }
    }

    private func activate(_ id: TerminalSession.ID) {
        live.removeAll { $0 == id }
        live.append(id)

        if live.count > WorkspaceLayout.liveSessionLimit {
            live.removeFirst(live.count - WorkspaceLayout.liveSessionLimit)
        }
    }

}
