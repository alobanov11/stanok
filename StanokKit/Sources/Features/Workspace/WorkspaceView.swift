import AppKit
import Combine
import SwiftUI

public struct WorkspaceView<Terminal: View>: View {

    private var knownSessionIDs: Set<TerminalSession.ID> {
        Set(store.sessions.map(\.id))
    }

    private var selectedSession: TerminalSession? {
        store.session(for: selection)
    }

    private var selectedFileBinding: Binding<URL?> {
        Binding(
            get: { selectedFile },
            set: { newValue in
                if let newValue {
                    fileSelection.reveal(newValue)
                } else {
                    selectedFile = nil
                }
            }
        )
    }

    private var fileSelection: FileSelectionController {
        FileSelectionController(
            selectedFile: $selectedFile,
            filesMode: $filesMode,
            store: store,
            navigator: navigator,
            session: { selectedSession }
        )
    }

    private var linkRouter: LinkRouter {
        LinkRouter(navigator: navigator, openFile: fileSelection.open)
    }

    private var branchActions: BranchActions {
        BranchActions.make(
            isOperating: branchStore.isOperating(selectedSession),
            session: { selectedSession },
            branchStore: branchStore,
            afterSwitch: afterBranchSwitch,
            fetch: { dispatchGitCommand(["fetch", "--all", "--prune"]) },
            pull: { dispatchGitCommand(["pull", "--ff-only"]) }
        )
    }

    private var agentCommands: AgentCommandRouter {
        AgentCommandRouter(dispatcher: dispatcher, tracker: processTracker)
    }

    private var previewWidth: CGFloat {
        (mainWidth / 2 - WorkspaceLayout.inset).rounded()
    }

    private var isPreviewSplit: Bool {
        WorkspaceGeometry.isPreviewSplit(hasPreview: navigator.current != nil, width: mainWidth)
    }

    @State
    private var model = WorkspaceModel()

    @State
    private var store = SessionStore()

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
    private var branchStore = GitBranchStore()

    @State
    private var branchTreeModel = BranchTreeModel()

    @State
    private var navigator = PreviewNavigator()

    @State
    private var selectedFile: URL?

    @State
    private var mainWidth: CGFloat = 0

    @State
    private var workingTreeAction: WorkingTreeAction?

    @State
    private var workingTreeError: String?

    @State
    private var isWorkingTreeBusy = false

    @State
    private var fileTreeModel = FileTreeModel()

    @State
    private var changeTreeModel = ChangeTreeModel()

    @State
    private var dispatcher = TerminalCommandDispatcher()

    @State
    private var processTracker = TabProcessTracker()

    @State
    private var cwdTracker = WorkingDirectoryTracker()

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
                .environment(\.openURL, OpenURLAction(handler: linkRouter.handleLink))

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
        .focusedValue(\.workspaceCommands, .make(
            toggleSidebar: toggleSidebar, selectFilesMode: selectFilesMode,
            session: selectedSession, store: store,
            selection: $selection, closeSession: closeSession
        ))
        .task { selectFirstIfNeeded() }
        .task(id: selection) { await git.refresh(selectedSession) }
        .task(id: selection) { await branchStore.refresh(selectedSession) }
        .task(id: selectedSession?.url) { await settleDirectoryChange() }
        .task(id: selectedSession?.id) { fileSelection.restoreWorkspace() }
        .onChange(of: selectedSession?.id) { _, _ in resetPreview() }
        .onChange(of: filesMode) { _, mode in
            guard mode == .branches else { return }

            Task { await branchStore.refresh(selectedSession) }
        }
        .onChange(of: selection) { _, new in
            guard let new else { return }

            activate(new)
        }
        .onChange(of: knownSessionIDs) { _, known in reconcileLiveSessions(known) }
        .onChange(
            of: git.snapshot(for: selectedSession)?.gitDirectory,
            initial: true
        ) { _, new in
            fileTreeModel.updateGitDirectory(new)
        }
        .onChange(of: git.snapshot(for: selectedSession), initial: true) { _, snapshot in
            changeTreeModel.apply(snapshot)
        }
        .onChange(of: branchStore.snapshot(for: selectedSession), initial: true) { _, snapshot in
            branchTreeModel.apply(snapshot)
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
            .padding(.top, WorkspaceGeometry.toggleTop)
            .padding(.leading, WorkspaceGeometry.toggleLeading(sidebarExpanded: isSidebarExpanded))
    }

    private var sidebar: some View {
        SessionList(
            store: store,
            live: Set(live),
            processUsage: processTracker.usage,
            insertAgentCommand: insertAgentCommand,
            copyAgentCommand: copyAgentCommand,
            selection: $selection
        )
    }

    private var header: some View {
        TerminalHeader(
            session: selectedSession,
            status: git.status(for: selectedSession),
            leadingInset: WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded),
            filesMode: filesMode,
            selectAll: { selectFilesMode(.all) },
            selectChanges: { selectFilesMode(.changes) },
            selectBranches: { selectFilesMode(.branches) },
            stashChanges: { workingTreeAction = .stash },
            discardChanges: { workingTreeAction = .discard },
            isBusy: branchStore.isOperating(selectedSession) || isWorkingTreeBusy
        )
        .modifier(
            WorkingTreeConfirmation(
                action: $workingTreeAction,
                failure: $workingTreeError,
                perform: perform
            )
        )
    }

    private var terminals: some View {
        ZStack {
            ForEach(store.sessions) { session in
                if live.contains(session.id) {
                    terminal(
                        session,
                        isVisible(session),
                        dispatcher.insertRequest(for: session.id),
                        { model.record($0)
                            dispatcher.markAtPrompt(session.id)
                            Task { await git.refresh(session) } },
                        { linkRouter.openTerminalLink($0, in: session) },
                        { store.setLiveTitle($0.isEmpty ? nil : $0, for: session.id) },
                        { _ in closeSession(session) },
                        { cwdTracker.report($0, for: session.id, into: store) }
                    )
                    .opacity(isVisible(session) ? 1 : 0)
                    .allowsHitTesting(isVisible(session))
                }
            }
        }
        .overlay(alignment: .top) { copyNoticeOverlay }
    }

    @ViewBuilder
    private var copyNoticeOverlay: some View {
        if
            let notice = dispatcher.copyNotice,
            notice.sessionID == nil || notice.sessionID == selection {
            CopyNoticeBanner()
                .padding(.top, WorkspaceLayout.headerHeight + 8)
                .transition(.opacity)
        }
    }

    private var main: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { mainWidth = $0 }
    }

    private var mainContent: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                terminals
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(WorkspaceCard())
            .padding(.trailing, isPreviewSplit ? previewWidth + WorkspaceLayout.inset : 0)

            if let entry = navigator.current {
                previewLayer(
                    entry,
                    leadingInset: isPreviewSplit
                        ? WorkspaceGeometry.expandedHeaderLeading
                        : WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded)
                )
                .frame(width: isPreviewSplit ? previewWidth : nil)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(WorkspaceGeometry.previewTransition(split: isPreviewSplit))
            }
        }
    }

    private let terminal: TerminalBuilder<Terminal>

    public init(@ViewBuilder terminal: @escaping TerminalBuilder<Terminal>) {
        self.terminal = terminal
    }

    private func previewLayer(_ entry: PreviewEntry, leadingInset: CGFloat) -> some View {
        PreviewLayer(
            entry: entry,
            leadingInset: leadingInset,
            previousName: navigator.previousName,
            onBack: stepBack,
            onClose: closePreview
        )
    }

    private func filesPanel(_ mode: FilePanelMode) -> some View {
        FilePanel(
            mode: mode,
            fileTreeModel: fileTreeModel,
            changeTreeModel: changeTreeModel,
            branchTreeModel: branchTreeModel,
            branchActions: branchActions,
            snapshot: git.snapshot(for: selectedSession),
            selected: selectedFileBinding,
            onOpen: fileSelection.open
        )
        .modifier(WorkspacePanelStyle(width: WorkspaceLayout.filesWidth))
    }

    private func isVisible(_ session: TerminalSession) -> Bool {
        session.id == selection && (navigator.current == nil || isPreviewSplit)
    }

    private func openFileTree() {
        fileTreeModel.open(
            selectedSession?.url,
            gitDirectory: git.snapshot(for: selectedSession)?.gitDirectory,
            onGitChange: { Task { await git.refresh(selectedSession) } }
        )
    }

    private func settleDirectoryChange() async {
        try? await Task.sleep(for: WorkspaceLayout.directorySettleDelay)
        guard !Task.isCancelled else { return }

        openFileTree()
        await git.refresh(selectedSession)
        await branchStore.refresh(selectedSession)
    }

    private func closeSession(_ session: TerminalSession) {
        if selection == session.id { selection = nil }

        live.removeAll { $0 == session.id }
        processTracker.endTracking(session.id)
        dispatcher.forget(session.id)
        withAnimation(.smooth(duration: 0.22)) { store.removeSession(session.id) }
    }

    private func copyAgentCommand(_ action: AgentResumeAction, _ sessionID: TerminalSession.ID?) {
        agentCommands.copy(action, for: sessionID)
    }

    private func insertAgentCommand(_ action: AgentResumeAction, _ sessionID: TerminalSession.ID?) {
        guard let sessionID, store.session(for: sessionID) != nil else {
            agentCommands.insert(action, into: nil)
            return
        }

        selection = sessionID
        activate(sessionID)
        agentCommands.insert(action, into: sessionID)
    }

    private func perform(_ action: WorkingTreeAction) async {
        guard let root = git.snapshot(for: selectedSession)?.root else { return }

        isWorkingTreeBusy = true
        let outcome = await GitWorkingTreeOperations.run(action, at: root)
        isWorkingTreeBusy = false

        guard outcome.succeeded else {
            workingTreeError = outcome.message
            return
        }

        await afterBranchSwitch()
    }

    private func afterBranchSwitch() async {
        await git.refresh(selectedSession)
        await branchStore.refresh(selectedSession)
        fileTreeModel.reloadAll()

        if case let .file(preview) = navigator.current {
            await navigator.openFile(preview.url)
        }
    }

    private func dispatchGitCommand(_ arguments: [String]) {
        guard let session = selectedSession else { return }

        let path = session.url.path(percentEncoded: false)
        let action = AgentResumeAction(executable: "git", arguments: ["-C", path] + arguments)
        dispatcher.dispatch(action, into: selection)
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
        let transition = FilePanelModeTransition.resolve(current: filesMode, requested: mode)
        let animation: Animation? = transition.animates
            ? .smooth(duration: WorkspaceLayout.toggleDuration)
            : nil

        withAnimation(animation) { filesMode = transition.nextMode }
        fileSelection.persistPanelMode()
    }

    private func selectFirstIfNeeded() {
        guard selection == nil else { return }

        selection = store.session(for: store.selectedSessionID)?.id ?? store.sessions.first?.id
    }

    private func reconcileLiveSessions(_ known: Set<TerminalSession.ID>) {
        let removed = live.filter { !known.contains($0) }
        live.removeAll { !known.contains($0) }
        for id in removed {
            processTracker.endTracking(id)
        }

        if let selection, !known.contains(selection) {
            self.selection = nil
        }
    }

    private func activate(_ id: TerminalSession.ID) {
        if !live.contains(id) { dispatcher.markAtPrompt(id) }

        live.removeAll { $0 == id }
        live.append(id)
        processTracker.beginTracking(id)

        if live.count > WorkspaceLayout.liveSessionLimit {
            let overflow = live.count - WorkspaceLayout.liveSessionLimit
            for evictedID in live.prefix(overflow) {
                processTracker.endTracking(evictedID)
            }
            live.removeFirst(overflow)
        }

        store.select(id)
    }

}
