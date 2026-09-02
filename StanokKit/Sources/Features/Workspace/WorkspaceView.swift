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

    private var navigator: PreviewNavigator {
        navigators.navigator(for: rootSession?.id)
    }

    private var linkRouter: LinkRouter {
        LinkRouter(navigator: navigator, openFile: inspectorControls.open)
    }

    private var inspectorControls: InspectorController {
        InspectorController(
            state: inspector,
            navigator: navigator,
            session: { selectedSession },
            rawMode: $filesPanelMode,
            persist: { sessionID, relative in
                store.updateWorkspace(sessionID) { $0.selectedFile = relative }
            }
        )
    }

    private var filesMode: FilePanelMode? {
        inspectorControls.mode
    }

    private var gitDirectories: [String] {
        guard let gitSnapshot else { return [] }

        return Array(Set([gitSnapshot.gitDirectory, gitSnapshot.commonDirectory])).sorted()
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
            selection: $selection,
            navigators: navigators,
            askSurface: { dispatcher.requestSurfaceClose($0) }
        )
    }

    private var branchActions: BranchActions {
        BranchActions.make(
            isOperating: branchStore.isOperating(selectedSession) || isWorkingTreeBusy,
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

    private var previewInset: CGFloat {
        previewMode == .split ? previewWidth + WorkspaceLayout.inset : 0
    }

    private var previewMode: PreviewMode {
        WorkspaceGeometry.previewMode(hasPreview: navigator.current != nil, width: mainWidth)
    }

    private var isClosingLiveSession: Binding<Bool> {
        Binding(get: { closeRequest != nil }, set: { if !$0 { closeRequest = nil } })
    }

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
    private var navigators = PreviewNavigators()

    @State
    private var commits = ReviewCommitStore()

    @State
    private var branchReviews = BranchReviewStore()

    @State
    private var branchRequest = UUID()

    @State
    private var branchRevalidation = UUID()

    @State
    private var mainWidth: CGFloat = 0

    @State
    private var closeRequest: TerminalSession?

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

    @Environment(\.touchedRepositories)
    private var touchedRepositories

    @State
    private var ownRepositories = TouchedRepositoriesModel()

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

            rightPanel
        }
        .overlay(alignment: .topLeading) { toggle }
        .background(TrafficLights(isHidden: !isSidebarExpanded).frame(width: 0, height: 0))
        .ignoresSafeArea()
        .background(WindowBackground().ignoresSafeArea())
        .frame(minWidth: 880, minHeight: 520)
        .focusedValue(\.workspaceCommands, .make(
            toggleSidebar: toggleSidebar, selectFilesMode: inspectorControls.select,
            session: selectedSession, store: store,
            selection: $selection, closeSession: liveSessions.requestClose
        ))
        .task { selectFirstIfNeeded() }
        .task(id: visiblePaneIDs) { await refreshPanes() }
        .task(id: selection) { await branchStore.refresh(selectedSession) }
        .task(id: selectedSession?.url) { await settleDirectoryChange() }
        .onChange(of: selection) { _, new in activate(new) }
        .onChange(of: knownSessionIDs) { _, known in
            liveSessions.reconcile(known)
            navigators.prune(roots: Set(store.roots.map(\.id)))
        }
        .onChange(of: filesMode) { _, mode in
            refreshBranches(for: mode)

            if mode == .all { openFileTree() } else { inspectorControls.closeTree() }
        }
        .modifier(
            InspectorSync(
                state: inspector,
                folder: inspectorFolder,
                gitRoot: inspectorGitRoot,
                snapshot: gitSnapshot,
                status: git,
                branchSnapshot: branchStore.snapshot(for: selectedSession),
                folders: sessionFolders,
                gitRoots: sessionGitRoots
            )
        )
        .modifier(SessionPersistence(store: store))
        .onChange(of: inspectorGitRoot, initial: true) { _, root in
            (touchedRepositories ?? ownRepositories).focus(on: root)
        }
        .onChange(of: gitSnapshot) { _, snapshot in
            if let root = snapshot?.root { revalidateBranchReview(root) }

            Task {
                await commits.refresh(
                    root: snapshot?.root,
                    branch: snapshot?.branch,
                    isClean: snapshot?.changes.isEmpty == true
                )
            }
        }
        .onChange(of: gitSnapshot) { _, _ in
            // Почему: коммит из терминала не трогает файл, но рибоны в превью уже не о том дереве
            Task { await navigator.refreshChanges() }
        }
        .task(id: agentChangesKey) { await pollAgentChanges() }
        .task(id: gitSnapshot?.root) { await pollCommits() }
        .task { await pollReachability() }
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
            closeSession: liveSessions.requestClose,
            selection: $selection
        )
    }

    private var panes: some View {
        GeometryReader { proxy in
            let frames = paneFrames(in: proxy.size)
            let resting = restingFrames(
                in: CGSize(width: proxy.size.width + previewInset, height: proxy.size.height)
            )

            ZStack(alignment: .topLeading) {
                ForEach(store.sessions) { session in
                    if live.contains(session.id) {
                        pane(
                            session,
                            frame: frames[session.id],
                            resting: resting[session.id],
                            container: proxy.size
                        )
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
        .confirmationDialog(
            "Закрыть терминал?",
            isPresented: isClosingLiveSession,
            presenting: closeRequest
        ) { session in
            Button("Закрыть", role: .destructive) { liveSessions.close(session) }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("В терминале ещё работает процесс — он будет прерван.")
        }
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
                .padding(.trailing, previewInset)

            if let entry = navigator.current {
                previewLayer(
                    entry,
                    leadingInset: previewMode == .split
                        ? WorkspaceGeometry.expandedHeaderLeading
                        : WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded)
                )
                .frame(width: previewMode == .split ? previewWidth : nil)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(WorkspaceGeometry.previewTransition(for: previewMode))
            }
        }
    }

    private let store = SessionStore.shared
    private let terminal: TerminalBuilder<Terminal>

    public init(@ViewBuilder terminal: @escaping TerminalBuilder<Terminal>) {
        self.terminal = terminal
    }
}

private extension WorkspaceView {

    @ViewBuilder
    var rightPanel: some View {
        if let filesMode, let folder = inspectorFolder, let root = inspectorGitRoot {
            filesPanel(filesMode, folder: folder, gitRoot: root)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    var agentChangesKey: String {
        "\(needsAgentChanges)|\(inspectorGitRoot ?? "")"
    }

    var needsAgentChanges: Bool {
        filesMode == .git
    }

    // Почему: карточки перечитывают файлы того репозитория, чьё ревью открыто
    func reviewRevision(_ kind: ReviewKind) -> String {
        switch kind {
        case .git: "\(git.revision(forRoot: inspectorGitRoot))"
        case let .branch(root, ref, _, isCurrent):
            "\(git.revision(forRoot: root))|" +
                "\(branchReviews.revision(root: root, branch: ref, isCurrent: isCurrent))"
        }
    }

    func activate(_ session: TerminalSession.ID?) {
        guard let session else { return }

        liveSessions.activate(session)
    }

    func refreshBranches(for mode: FilePanelMode?) {
        guard mode == .git else { return }

        Task { await branchStore.refresh(selectedSession) }
    }

    func pollAgentChanges() async {
        // Почему: панель могла смениться, гасить нужно свой проход, а не чужой
        let scope = inspectorGitRoot

        while !Task.isCancelled, needsAgentChanges {
            await (touchedRepositories ?? ownRepositories).refresh()
            try? await Task.sleep(for: .seconds(20))
        }

        // Почему: закрытая панель не должна дочитывать репозитории в фоне
        (touchedRepositories ?? ownRepositories).stop(scope)
    }

    func pollCommits() async {
        while !Task.isCancelled {
            await commits.refresh(
                root: gitSnapshot?.root,
                branch: gitSnapshot?.branch,
                isClean: gitSnapshot?.changes.isEmpty == true
            )

            try? await Task.sleep(for: .seconds(60))
        }
    }

    func pollReachability() async {
        while !Task.isCancelled {
            await store.refreshReachability()
            try? await Task.sleep(for: .seconds(15))
        }
    }

    // Почему: открытое ревью ветки должно пережить инвалидацию, а не остаться пустым
    func revalidateBranchReview(_ root: String) {
        guard case let .review(.branch(open, ref, name, was)) = navigator.current, open == root
        else { return }

        branchReviews.forget(root: root)

        // Почему: после checkout прежняя ветка перестала быть текущей, её дерево уже чужое
        let isCurrent = gitSnapshot?.branch.map { ref == "refs/heads/" + $0 } ?? false
        // Почему: пока грузим, рабочая группа может смениться — правим тот же навигатор
        let target = navigator
        let navigation = target.generation
        let generation = UUID()
        branchRevalidation = generation

        Task {
            let ready = await branchReviews.load(root: root, branch: ref, isCurrent: isCurrent)

            guard ready, isCurrent != was, branchRevalidation == generation else { return }
            guard target.generation == navigation, shows(target, root: root, ref: ref) else { return }

            target.retitleReview(
                .branch(root: root, ref: ref, name: name, isCurrent: isCurrent)
            )
        }
    }

    func shows(_ target: PreviewNavigator, root: String, ref: String) -> Bool {
        guard case let .review(.branch(open, live, _, _)) = target.current else { return false }

        return open == root && live == ref
    }

    // Почему: ревью ветки открывается уже с данными, иначе панель мигает пустотой
    func openBranchReview(_ root: String, _ ref: GitBranchRef) {
        let generation = UUID()
        branchRequest = generation

        // Почему: пока грузились данные, человек мог уйти на файл или закрыть превью
        let target = navigator
        let navigation = target.generation

        Task {
            let ready = await branchReviews.load(
                root: root,
                branch: ref.fullName,
                isCurrent: ref.isCurrent
            )

            guard ready, branchRequest == generation, target.generation == navigation
            else { return }

            target.openReview(.branch(
                root: root,
                ref: ref.fullName,
                name: ref.displayName,
                isCurrent: ref.isCurrent
            ))
        }
    }

    func hasReview(_ kind: ReviewKind) -> Bool {
        !reviewFiles(kind).isEmpty
    }

    func pane(
        _ session: TerminalSession,
        frame: CGRect?,
        resting: CGRect?,
        container: CGSize
    ) -> some View {
        let rect = frame ?? resting ?? CGRect(origin: .zero, size: container)
        let isShown = frame != nil && previewMode != .fullScreen
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

    func paneCard(
        _ session: TerminalSession,
        isShown: Bool,
        isFocused: Bool,
        isLeading: Bool
    ) -> some View {
        terminalContent(session, isShown: isShown, isFocused: isFocused)
            // Почему: под шапкой лежит живой первый ряд, а не переполнение скролла
            .padding(.top, isLeading ? WorkspaceLayout.headerHeight : 0)
            .overlay(alignment: .top) {
                if isLeading { header(session) }
            }
            .overlay(alignment: .topTrailing) {
                if !isLeading { floatingMenu(session) }
            }
            .modifier(WorkspaceCard())
    }

    func floatingMenu(_ session: TerminalSession) -> some View {
        TerminalActionsMenu(
            split: { direction in split(session, direction) },
            newTerminal: { addSession(at: session.url) },
            close: { liveSessions.requestClose(session) }
        )
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    func header(_ session: TerminalSession) -> some View {
        TerminalHeader(
            session: session,
            status: git.status(for: session),
            leadingInset: WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded),
            filesMode: filesMode,
            isBusy: branchStore.isOperating(session) || isWorkingTreeBusy,
            selectAll: { selectFiles(.all, in: session) },
            selectGit: { selectFiles(.git, in: session) },
            stashChanges: { requestWorkingTree(.stash, for: session) },
            discardChanges: { requestWorkingTree(.discard, for: session) },
            split: { direction in split(session, direction) },
            newTerminal: { addSession(at: session.url) },
            close: { liveSessions.requestClose(session) }
        )
    }

    func terminalContent(
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
                onCommandFinished: { _ in
                    dispatcher.markAtPrompt(session.id)
                    Task { await git.refresh(session) }
                },
                onOpenURL: { linkRouter.openTerminalLink($0, in: session) },
                onTitleChanged: { store.setLiveTitle($0.isEmpty ? nil : $0, for: session.id) },
                onCloseRequested: { processAlive in
                    if processAlive {
                        closeRequest = session
                    } else {
                        liveSessions.close(session)
                    }
                },
                onPwdChanged: { WorkingDirectoryTracker.report($0, for: session.id, into: store) },
                onInput: { dispatcher.markBusy(session.id) },
                onInsertHandled: { dispatcher.markInserted(session.id, request: $0) },
                closeRequest: dispatcher.closeRequest(for: session.id),
                onCloseHandled: { dispatcher.markCloseHandled(session.id, request: $0) },
                onFocused: { selection = session.id }
            )
        )
    }

    func filesPanel(
        _ mode: FilePanelMode,
        folder: URL,
        gitRoot: String
    ) -> some View {
        FilePanel(
            mode: mode,
            fileTreeModel: inspector.fileTree(for: folder),
            changeTreeModel: inspector.changeTree(for: gitRoot),
            branchTreeModel: inspector.branchTree(for: gitRoot),
            touchedRepositories: touchedRepositories ?? ownRepositories,
            branchActions: branchActions,
            onOpenBranch: openBranchReview,
            inspector: inspector,
            branches: branchStore,
            snapshot: gitSnapshot,
            selected: inspectorControls.selectedFile,
            onOpen: inspectorControls.open,
            hasGitReview: hasReview(.git),
            onReview: { navigator.openReview($0) }
        )
        .modifier(WorkspacePanelStyle(width: WorkspaceLayout.filesWidth))
    }

    func reviewFiles(_ kind: ReviewKind) -> [ReviewFile] {
        switch kind {
        case .git:
            guard let snapshot = gitSnapshot else { return [] }

            return ReviewFiles.build(
                root: snapshot.root,
                changes: snapshot.changes,
                commits: commits.commits(for: snapshot.root),
                repository: nil
            )

        case let .branch(root, ref, _, current):
            guard let review = branchReviews.review(root: root, branch: ref, isCurrent: current)
            else { return [] }

            return ReviewFiles.build(
                root: root,
                changes: review.changes,
                commits: review.commits,
                repository: nil
            )
        }
    }

    func previewLayer(_ entry: PreviewEntry, leadingInset: CGFloat) -> some View {
        PreviewLayer(
            entry: entry,
            reviewFiles: reviewFiles,
            leadingInset: leadingInset,
            previousName: navigator.previousName,
            onBack: stepBack,
            revision: reviewRevision,
            onOpen: inspectorControls.open,
            onClose: closePreview
        )
    }

    func paneFrames(in size: CGSize) -> [TerminalSession.ID: CGRect] {
        guard let paneLayout else { return [:] }

        return SplitFrames.rects(for: paneLayout, in: size, gap: WorkspaceLayout.inset)
    }

    func restingFrames(in area: CGSize) -> [TerminalSession.ID: CGRect] {
        var frames: [TerminalSession.ID: CGRect] = [:]

        for root in store.roots where root.id != rootSession?.id {
            let layout = root.layout ?? .leaf(root.id)
            for (id, rect) in SplitFrames.rects(
                for: layout,
                in: area,
                gap: WorkspaceLayout.inset
            ) {
                frames[id] = rect
            }
        }

        return frames
    }

    func selectFiles(_ mode: FilePanelMode, in session: TerminalSession) {
        if selection != session.id { selection = session.id }

        inspectorControls.select(mode)
    }

    func openFileTree() {
        let session = selectedSession

        inspectorControls.openTree(gitDirectories: gitDirectories) {
            Task { await git.refresh(session) }
        }
    }

    func refreshPanes() async {
        var seen: Set<String> = []
        let unique = visiblePanes.filter { seen.insert($0.url.path(percentEncoded: false)).inserted }

        let refreshes = unique.map { pane in Task { await git.refresh(pane) } }

        for refresh in refreshes {
            await refresh.value
        }
    }

    func settleDirectoryChange() async {
        try? await Task.sleep(for: WorkspaceLayout.directorySettleDelay)
        guard !Task.isCancelled else { return }

        // Почему: на старте раскрытие дерева и FSEvents дают заметный фриз впустую
        if filesMode == .all { openFileTree() }

        await git.refresh(selectedSession)
        await branchStore.refresh(selectedSession)
    }

    func split(_ session: TerminalSession, _ direction: SplitDirection) {
        withAnimation(.smooth(duration: 0.22)) {
            guard let pane = store.splitSession(session.id, direction: direction) else { return }

            selection = pane.id
        }
    }

    func addSession(at url: URL) {
        withAnimation(.smooth(duration: 0.22)) { selection = store.addSession(url: url).id }
    }

    func copyAgentCommand(_ action: AgentResumeAction, _ sessionID: TerminalSession.ID?) {
        agentCommands.copy(action, for: sessionID)
    }

    func insertAgentCommand(_ action: AgentResumeAction, _ sessionID: TerminalSession.ID?) {
        guard let sessionID, store.session(for: sessionID) != nil else {
            agentCommands.insert(action, into: nil)
            return
        }

        selection = sessionID
        liveSessions.activate(sessionID)
        agentCommands.insert(action, into: sessionID)
    }

    func requestWorkingTree(_ action: WorkingTreeAction, for session: TerminalSession) {
        workingTreeTarget = session
        workingTreeAction = action
    }

    func perform(_ action: WorkingTreeAction) async {
        guard !isWorkingTreeBusy else { return }
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

    func afterBranchSwitch(_ sessionID: TerminalSession.ID) async {
        await settleWorkingTree(store.session(for: sessionID))
    }

    func settleWorkingTree(_ session: TerminalSession?) async {
        guard let session else { return }

        await git.refresh(session)
        await branchStore.refresh(session)
        inspector.fileTree(for: session.url).reloadAll()

        let target = navigators.navigator(for: store.root(of: session.id)?.id)
        if case let .file(preview) = target.current {
            await target.reloadFile(preview.url)
        }
    }

    func dispatchGitCommand(_ arguments: [String]) {
        guard let session = selectedSession else { return }

        let path = session.url.path(percentEncoded: false)
        let action = AgentResumeAction(executable: "git", arguments: ["-C", path] + arguments)
        dispatcher.dispatch(action, into: selection)
    }

    func closePreview() {
        navigator.clear()
    }

    func stepBack() {
        navigator.pop()
    }

    func toggleSidebar() {
        withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) {
            isSidebarExpanded.toggle()
        }
    }

    func selectFirstIfNeeded() {
        guard selection == nil else { return }

        selection = store.session(for: store.selectedSessionID)?.id ?? store.sessions.first?.id
    }
}
