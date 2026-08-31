import AppKit
import Combine
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

    private var selectedFileBinding: Binding<URL?> {
        Binding(
            get: { selectedFile },
            set: { newValue in
                if let newValue {
                    reveal(newValue)
                } else {
                    selectedFile = nil
                }
            }
        )
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

    @AppStorage(WorkspaceDefaults.Keys.isSidebarExpanded)
    private var isSidebarExpanded = WorkspaceDefaults.Defaults.isSidebarExpanded

    @State
    private var filesMode: FilePanelMode?

    @State
    private var live: [TerminalSession.ID] = []

    @State
    private var git = GitStatusStore()

    @State
    private var navigator = PreviewNavigator()

    @State
    private var selectedFile: URL?

    @State
    private var fileTreeModel = FileTreeModel()

    @State
    private var changeTreeModel = ChangeTreeModel()

    @Environment(\.scenePhase)
    private var scenePhase

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
                .environment(\.openURL, OpenURLAction(handler: handleLink))

            if let filesMode {
                filesPanel(filesMode)
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
        .task(id: selectedRepository?.url) { openFileTree() }
        .task(id: selectedRepository?.id) { restoreWorkspace() }
        .onChange(of: selectedRepository?.id) { _, _ in resetPreview() }
        .onChange(of: selection) { _, new in
            guard let new else { return }

            activate(new)
        }
        .onChange(of: store.repositories) { _, _ in reconcileLiveSessions() }
        .onChange(
            of: git.snapshot(for: selectedRepository)?.gitDirectory,
            initial: true
        ) { _, new in
            fileTreeModel.updateGitDirectory(new)
        }
        .onChange(of: git.snapshot(for: selectedRepository), initial: true) { _, snapshot in
            changeTreeModel.apply(snapshot)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }

            store.flushPendingSave()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)
        ) { _ in
            store.flushPendingSave()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
            store.flushPendingSave()
        }
    }

    private var toggle: some View {
        SidebarToggle(action: toggleSidebar)
            .padding(.top, toggleTop)
            .padding(.leading, isSidebarExpanded ? outsideLeading : insideOffset)
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
            filesMode: filesMode,
            selectAll: { selectFilesMode(.all) },
            selectChanges: { selectFilesMode(.changes) }
        )
    }

    private var terminals: some View {
        ZStack {
            ForEach(store.repositories) { repository in
                ForEach(repository.sessions) { session in
                    if live.contains(session.id) {
                        terminal(
                            repository,
                            session,
                            isVisible(session),
                            { model.record($0)
                                Task { await git.refresh(repository) } },
                            { openTerminalLink($0, in: repository) },
                            { _ in closeSession(session) }
                        )
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

            if let entry = navigator.current {
                previewLayer(entry)
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
        @escaping (CommandRun) -> Void,
        @escaping (String) -> Void,
        @escaping (Bool) -> Void
    ) -> Terminal

    public init(
        @ViewBuilder terminal: @escaping (
            Repository,
            TerminalSession,
            Bool,
            @escaping (CommandRun) -> Void,
            @escaping (String) -> Void,
            @escaping (Bool) -> Void
        ) -> Terminal
    ) {
        self.terminal = terminal
    }

    @ViewBuilder
    private func previewLayer(_ entry: PreviewEntry) -> some View {
        Group {
            switch entry {
            case let .file(preview):
                PreviewPanel(
                    preview: preview,
                    leadingInset: headerLeading,
                    previousName: navigator.previousName,
                    onBack: stepBack
                )

            case let .web(preview):
                WebPreviewPanel(
                    preview: preview,
                    leadingInset: headerLeading,
                    previousName: navigator.previousName,
                    onBack: stepBack
                )
            }
        }
        .background {
            WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius)
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .zIndex(1)
        .transition(.opacity)
    }

    private func filesPanel(_ mode: FilePanelMode) -> some View {
        FilePanel(
            mode: mode,
            fileTreeModel: fileTreeModel,
            changeTreeModel: changeTreeModel,
            snapshot: git.snapshot(for: selectedRepository),
            selected: selectedFileBinding,
            onOpen: open
        )
        .frame(width: WorkspaceLayout.filesWidth)
        .background { WorkspaceLayout.cardStyle.background(radius: WorkspaceLayout.cardRadius) }
        .clipShape(.rect(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous))
        .padding(.trailing, WorkspaceLayout.inset)
        .padding(.vertical, WorkspaceLayout.inset)
    }

    private static func contains(_ root: URL, _ candidate: URL) -> Bool {
        let base = root.standardizedFileURL.path(percentEncoded: false)
        let target = candidate.standardizedFileURL.path(percentEncoded: false)
        guard target != base else { return true }

        return target.hasPrefix(base.hasSuffix("/") ? base : base + "/")
    }

    private static func resolvedURL(from raw: String, relativeTo base: URL) -> URL? {
        if let url = URL(string: raw), url.scheme != nil { return url }
        if raw.hasPrefix("/") { return URL(fileURLWithPath: raw) }

        return base.appending(path: raw)
    }

    private static func relativePath(for url: URL, in root: URL) -> String? {
        guard contains(root, url) else { return nil }

        let base = root.standardizedFileURL.path(percentEncoded: false)
        let target = url.standardizedFileURL.path(percentEncoded: false)
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard target != base, target.hasPrefix(prefix) else { return nil }

        return String(target.dropFirst(prefix.count))
    }

    private static func resolvedURL(relative: String, in root: URL) -> URL? {
        guard !relative.isEmpty, !relative.hasPrefix("/") else { return nil }
        guard !relative.split(separator: "/").contains("..") else { return nil }

        return root.appending(path: relative)
    }

    private static func resolvedSelectedFile(from repository: Repository) -> URL? {
        guard let relative = repository.workspace.selectedFile else { return nil }

        return resolvedURL(relative: relative, in: repository.url)
    }

    private static func filePanelMode(from raw: String?) -> FilePanelMode? {
        switch raw {
        case "all": return .all
        case "changes": return .changes
        default: return nil
        }
    }

    private static func rawValue(for mode: FilePanelMode?) -> String? {
        switch mode {
        case .all: return "all"
        case .changes: return "changes"
        case nil: return nil
        }
    }

    private func isVisible(_ session: TerminalSession) -> Bool {
        session.id == selection && navigator.current == nil
    }

    private func openFileTree() {
        fileTreeModel.open(
            selectedRepository?.url,
            gitDirectory: git.snapshot(for: selectedRepository)?.gitDirectory,
            onGitChange: { Task { await git.refresh(selectedRepository) } }
        )
    }

    private func restoreWorkspace() {
        guard let repository = selectedRepository else { return }

        if let resolved = Self.resolvedSelectedFile(from: repository) {
            selectedFile = resolved
        }

        filesMode = Self.filePanelMode(from: repository.workspace.panelMode)
    }

    private func open(_ url: URL) {
        reveal(url)

        Task {
            await navigator.openFile(url)
        }
    }

    private func reveal(_ url: URL) {
        guard
            let repository = selectedRepository,
            Self.contains(repository.url, url)
        else { return }

        selectedFile = url

        if filesMode != .changes {
            showAllFiles()
        }

        if let relative = Self.relativePath(for: url, in: repository.url) {
            store.updateWorkspace(repository.id) { $0.selectedFile = relative }
        }
    }

    private func showAllFiles() {
        guard filesMode != .all else { return }

        if filesMode == nil {
            withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) { filesMode = .all }
        } else {
            filesMode = .all
        }

        persistPanelMode()
    }

    private func route(_ url: URL) {
        if url.scheme == "http" || url.scheme == "https" {
            navigator.openWeb(url)
            return
        }

        guard url.isFileURL else {
            NSWorkspace.shared.open(url)
            return
        }

        open(URL(fileURLWithPath: url.path))
    }

    private func handleLink(_ url: URL) -> OpenURLAction.Result {
        route(url)
        return .handled
    }

    private func closeSession(_ session: TerminalSession) {
        if selection == session.id { selection = nil }

        live.removeAll { $0 == session.id }
        withAnimation(.smooth(duration: 0.22)) { store.removeSession(session.id) }
    }

    private func openTerminalLink(_ raw: String, in repository: Repository) {
        guard let url = Self.resolvedURL(from: raw, relativeTo: repository.url) else { return }

        route(url)
    }

    private func closePreview() {
        navigator.clear()
    }

    private func stepBack() {
        navigator.pop()
    }

    private func resetPreview() {
        navigator.clear()
        selectedFile = nil
    }

    private func toggleSidebar() {
        withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) {
            isSidebarExpanded.toggle()
        }
    }

    private func selectFilesMode(_ mode: FilePanelMode) {
        if filesMode == mode {
            withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) { filesMode = nil }
        } else if filesMode == nil {
            withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) { filesMode = mode }
        } else {
            filesMode = mode
        }

        persistPanelMode()
    }

    private func persistPanelMode() {
        guard let repository = selectedRepository else { return }

        store.updateWorkspace(repository.id) { $0.panelMode = Self.rawValue(for: filesMode) }
    }

    private func selectFirstIfNeeded() {
        guard selection == nil else { return }
        guard let repository = store.repositories.first else { return }

        let remembered = repository.workspace.lastSessionID
            .flatMap { id in repository.sessions.first { $0.id == id } }

        selection = (remembered ?? repository.sessions.first)?.id
    }

    private func reconcileLiveSessions() {
        let known = Set(store.repositories.flatMap { $0.sessions.map(\.id) })
        live.removeAll { !known.contains($0) }

        if let selection, !known.contains(selection) {
            self.selection = nil
        }
    }

    private func activate(_ id: TerminalSession.ID) {
        live.removeAll { $0 == id }
        live.append(id)

        if live.count > WorkspaceLayout.liveSessionLimit {
            live.removeFirst(live.count - WorkspaceLayout.liveSessionLimit)
        }

        guard let repositoryID = store.repository(hosting: id)?.id else { return }

        store.touch(repositoryID)
        store.updateWorkspace(repositoryID) { $0.lastSessionID = id }
    }

}
