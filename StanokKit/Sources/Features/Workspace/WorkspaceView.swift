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

    private var rootSession: TerminalSession? {
        guard let selection else { return nil }

        return store.root(of: selection)
    }

    private var visiblePanes: [TerminalSession] {
        guard let rootSession else { return [] }

        return store.panes(of: rootSession)
    }

    private var visiblePaneIDs: [TerminalSession.ID] {
        visiblePanes.map(\.id)
    }

    private var paneLayout: SplitLayout? {
        guard let rootSession else { return nil }

        return rootSession.layout ?? .leaf(rootSession.id)
    }

    private var linkRouter: LinkRouter {
        LinkRouter(navigator: navigator, openFile: inspectorControls.open)
    }

    private var inspectorControls: InspectorController {
        InspectorController(
            state: inspector,
            navigator: navigator,
            session: { selectedSession },
            rawMode: $filesPanelMode
        )
    }

    private var filesMode: FilePanelMode? {
        inspectorControls.mode
    }

    private var gitSnapshot: GitSnapshot? {
        git.snapshot(for: selectedSession)
    }

    private var inspectorFolder: URL? {
        selectedSession?.url
    }

    private var inspectorGitRoot: String? {
        gitSnapshot?.root ?? inspectorFolder.map { InspectorState.key(for: $0) }
    }

    private var sessionFolders: Set<URL> {
        Set(store.sessions.map(\.url))
    }

    private var sessionGitRoots: Set<String> {
        Set(store.sessions.compactMap { git.snapshot(for: $0)?.root })
            .union(sessionFolders.map { InspectorState.key(for: $0) })
    }

    private var newTerminalFolder: URL {
        selectedSession?.url ?? FileManager.default.homeDirectoryForCurrentUser
    }

    private var liveSessions: LiveSessionController {
        LiveSessionController(
            store: store,
            dispatcher: dispatcher,
            processTracker: processTracker,
            live: $live,
            selection: $selection
        )
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

    private var isPreviewFullScreen: Bool {
        navigator.current != nil && !isPreviewSplit
    }

    @State
    private var model = WorkspaceModel()

    @State
    private var store = SessionStore()

    @State
    private var selection: TerminalSession.ID?

    @AppStorage(WorkspaceDefaults.Keys.isSidebarExpanded)
    private var isSidebarExpanded = WorkspaceDefaults.Defaults.isSidebarExpanded

    @AppStorage(WorkspaceDefaults.Keys.filesPanelMode)
    private var filesPanelMode = WorkspaceDefaults.Defaults.filesPanelMode

    @State
    private var inspector = InspectorState()

    @State
    private var live: [TerminalSession.ID] = []

    @State
    private var git = GitStatusStore()

    @State
    private var branchStore = GitBranchStore()

    @State
    private var navigator = PreviewNavigator()

    @State
    private var mainWidth: CGFloat = 0

    @State
    private var workingTreeAction: WorkingTreeAction?

    @State
    private var workingTreeTarget: TerminalSession?

    @State
    private var workingTreeError: String?

    @State
    private var isWorkingTreeBusy = false

    @State
    private var dispatcher = TerminalCommandDispatcher()

    @State
    private var processTracker = TabProcessTracker()

    @State
    private var cwdTracker = WorkingDirectoryTracker()

    public var body: some View {
        HStack(spacing: 0) {
            if isSidebarExpanded {
                sidebar
                    .frame(width: WorkspaceLayout.sidebarWidth)
                    .padding(.top, WorkspaceLayout.sidebarTopInset)
                    .padding(.bottom, WorkspaceLayout.inset)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            main
                .padding(.leading, isSidebarExpanded ? 0 : WorkspaceLayout.inset)
                .padding(.trailing, WorkspaceLayout.inset)
                .padding(.vertical, WorkspaceLayout.inset)
                .environment(\.openURL, OpenURLAction(handler: linkRouter.handleLink))

            if let filesMode, let folder = inspectorFolder, let root = inspectorGitRoot {
                filesPanel(filesMode, folder: folder, gitRoot: root)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) { toggle }
        .background(TrafficLights(isHidden: !isSidebarExpanded).frame(width: 0, height: 0))
        .ignoresSafeArea()
        .background(WindowBackground().ignoresSafeArea())
        .frame(minWidth: 880, minHeight: 520)
        .focusedValue(\.workspaceCommands, .make(
            toggleSidebar: toggleSidebar, selectFilesMode: inspectorControls.select,
            session: selectedSession, store: store,
            selection: $selection, closeSession: liveSessions.close
        ))
        .task { selectFirstIfNeeded() }
        .task(id: visiblePaneIDs) { await refreshPanes() }
        .task(id: selection) { await branchStore.refresh(selectedSession) }
        .task(id: selectedSession?.url) { await settleDirectoryChange() }
        .onChange(of: selection) { _, new in
            guard let new else { return }

            liveSessions.activate(new)
        }
        .onChange(of: knownSessionIDs) { _, known in liveSessions.reconcile(known) }
        .onChange(of: filesMode) { _, mode in
            guard mode == .branches else { return }

            Task { await branchStore.refresh(selectedSession) }
        }
        .modifier(
            InspectorSync(
                state: inspector,
                folder: inspectorFolder,
                gitRoot: inspectorGitRoot,
                snapshot: gitSnapshot,
                branchSnapshot: branchStore.snapshot(for: selectedSession),
                folders: sessionFolders,
                gitRoots: sessionGitRoots
            )
        )
        .modifier(SessionPersistence(store: store))
    }

    private var toggle: some View {
        SidebarToggle(
            toggle: toggleSidebar,
            addTerminal: isSidebarExpanded ? { addSession(at: newTerminalFolder) } : nil
        )
        .padding(.top, WorkspaceGeometry.toggleTop)
        .padding(.leading, WorkspaceGeometry.toggleLeading(sidebarExpanded: isSidebarExpanded))
    }

    private var sidebar: some View {
        SessionList(
            store: store,
            live: Set(live),
            insertAgentCommand: insertAgentCommand,
            copyAgentCommand: copyAgentCommand,
            closeSession: liveSessions.close,
            selection: $selection
        )
    }

    private var panes: some View {
        GeometryReader { proxy in
            let frames = paneFrames(in: proxy.size)

            ZStack(alignment: .topLeading) {
                ForEach(store.sessions) { session in
                    if live.contains(session.id) {
                        pane(session, frame: frames[session.id])
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .overlay(alignment: .top) { copyNoticeOverlay }
        .modifier(
            WorkingTreeConfirmation(
                action: $workingTreeAction,
                failure: $workingTreeError,
                perform: perform
            )
        )
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
            panes
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

    private func pane(_ session: TerminalSession, frame: CGRect?) -> some View {
        let rect = frame ?? CGRect(origin: .zero, size: WorkspaceLayout.hiddenPaneSize)
        let isShown = frame != nil && !isPreviewFullScreen
        let isFocused = isShown && session.id == selection

        return paneCard(
            session,
            isShown: isShown,
            isFocused: isFocused,
            isLeading: rect.minX < 1 && rect.minY < 1
        )
        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
        .offset(x: rect.minX, y: rect.minY)
        .opacity(isShown ? (isFocused ? 1 : WorkspaceLayout.unfocusedPaneOpacity) : 0)
        .allowsHitTesting(isShown)
    }

    private func paneCard(
        _ session: TerminalSession,
        isShown: Bool,
        isFocused: Bool,
        isLeading: Bool
    ) -> some View {
        VStack(spacing: 0) {
            if isLeading { header(session) }

            terminalContent(session, isShown: isShown, isFocused: isFocused)
        }
        .modifier(WorkspaceCard())
        .overlay(alignment: .topTrailing) {
            if !isLeading { floatingMenu(session) }
        }
    }

    private func floatingMenu(_ session: TerminalSession) -> some View {
        TerminalActionsMenu(
            split: { direction in split(session, direction) },
            newTerminal: { addSession(at: session.url) },
            close: { liveSessions.close(session) }
        )
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    private func header(_ session: TerminalSession) -> some View {
        TerminalHeader(
            session: session,
            status: git.status(for: session),
            leadingInset: WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded),
            filesMode: filesMode,
            isBusy: branchStore.isOperating(session) || isWorkingTreeBusy,
            selectAll: { selectFiles(.all, in: session) },
            selectChanges: { selectFiles(.changes, in: session) },
            selectBranches: { selectFiles(.branches, in: session) },
            stashChanges: { requestWorkingTree(.stash, for: session) },
            discardChanges: { requestWorkingTree(.discard, for: session) },
            split: { direction in split(session, direction) },
            newTerminal: { addSession(at: session.url) },
            close: { liveSessions.close(session) }
        )
    }

    private func terminalContent(
        _ session: TerminalSession,
        isShown: Bool,
        isFocused: Bool
    ) -> some View {
        terminal(
            TerminalRequest(
                session: session,
                isVisible: isShown,
                isFocused: isFocused,
                insertRequest: dispatcher.insertRequest(for: session.id),
                onCommandFinished: { run in
                    model.record(run)
                    dispatcher.markAtPrompt(session.id)
                    Task { await git.refresh(session) }
                },
                onOpenURL: { linkRouter.openTerminalLink($0, in: session) },
                onTitleChanged: { store.setLiveTitle($0.isEmpty ? nil : $0, for: session.id) },
                onCloseRequested: { _ in liveSessions.close(session) },
                onPwdChanged: { cwdTracker.report($0, for: session.id, into: store) },
                onFocused: { selection = session.id }
            )
        )
    }

    private func filesPanel(
        _ mode: FilePanelMode,
        folder: URL,
        gitRoot: String
    ) -> some View {
        FilePanel(
            mode: mode,
            fileTreeModel: inspector.fileTree(for: folder),
            changeTreeModel: inspector.changeTree(for: gitRoot),
            branchTreeModel: inspector.branchTree(for: gitRoot),
            branchActions: branchActions,
            snapshot: gitSnapshot,
            selected: inspectorControls.selectedFile,
            onOpen: inspectorControls.open
        )
        .modifier(WorkspacePanelStyle(width: WorkspaceLayout.filesWidth))
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

    private func paneFrames(in size: CGSize) -> [TerminalSession.ID: CGRect] {
        guard let paneLayout else { return [:] }

        return SplitFrames.rects(for: paneLayout, in: size, gap: WorkspaceLayout.inset)
    }

    private func selectFiles(_ mode: FilePanelMode, in session: TerminalSession) {
        if selection != session.id { selection = session.id }

        inspectorControls.select(mode)
    }

    private func openFileTree() {
        let session = selectedSession

        inspectorControls.openTree(gitDirectory: gitSnapshot?.gitDirectory) {
            Task { await git.refresh(session) }
        }
    }

    private func refreshPanes() async {
        for pane in visiblePanes {
            await git.refresh(pane)
        }
    }

    private func settleDirectoryChange() async {
        try? await Task.sleep(for: WorkspaceLayout.directorySettleDelay)
        guard !Task.isCancelled else { return }

        openFileTree()
        await git.refresh(selectedSession)
        await branchStore.refresh(selectedSession)
    }

    private func split(_ session: TerminalSession, _ direction: SplitDirection) {
        withAnimation(.smooth(duration: 0.22)) {
            guard let pane = store.splitSession(session.id, direction: direction) else { return }

            selection = pane.id
        }
    }

    private func addSession(at url: URL) {
        withAnimation(.smooth(duration: 0.22)) { selection = store.addSession(url: url).id }
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
        liveSessions.activate(sessionID)
        agentCommands.insert(action, into: sessionID)
    }

    private func requestWorkingTree(_ action: WorkingTreeAction, for session: TerminalSession) {
        workingTreeTarget = session
        workingTreeAction = action
    }

    private func perform(_ action: WorkingTreeAction) async {
        guard
            let target = workingTreeTarget ?? selectedSession,
            let root = git.snapshot(for: target)?.root
        else { return }

        isWorkingTreeBusy = true
        let outcome = await GitWorkingTreeOperations.run(action, at: root)
        isWorkingTreeBusy = false

        guard outcome.succeeded else {
            workingTreeError = outcome.message
            return
        }

        await settleWorkingTree(target)
    }

    private func afterBranchSwitch() async {
        await settleWorkingTree(selectedSession)
    }

    private func settleWorkingTree(_ session: TerminalSession?) async {
        guard let session else { return }

        await git.refresh(session)
        await branchStore.refresh(session)
        inspector.fileTree(for: session.url).reloadAll()

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

    private func toggleSidebar() {
        withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) {
            isSidebarExpanded.toggle()
        }
    }

    private func selectFirstIfNeeded() {
        guard selection == nil else { return }

        selection = store.session(for: store.selectedSessionID)?.id ?? store.sessions.first?.id
    }
}
