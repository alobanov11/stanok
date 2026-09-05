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
        selectedSession
    }

    // Почему: порядок в ряду задают сами терминалы, поэтому возврат скрытого не тасует соседей
    private var visiblePanes: [TerminalSession] {
        store.sessions.filter { store.visible.contains($0.id) }
    }

    private var isVertical: Bool {
        WorkspaceGeometry.isVertical(areaSize)
    }

    // Почему: полосу решает внешний размер, иначе её толщина влияла бы на саму себя
    private var needsStrip: Bool {
        guard let measured else { return false }

        return store.sessions.count > fit(in: measured, preview: previewInset(in: measured))
    }

    private var stripInset: CGFloat {
        guard needsStrip else { return 0 }

        let thickness = isVertical ? WorkspaceLayout.stripHeight : WorkspaceLayout.stripWidth

        return thickness + WorkspaceLayout.inset
    }

    // Почему: полоса миниатюр забирает место у терминалов, поэтому ёмкость считаем без неё
    private var contentSize: CGSize {
        CGSize(
            width: max(areaSize.width - (isVertical ? 0 : stripInset), 0),
            height: max(areaSize.height - (isVertical ? stripInset : 0), 0)
        )
    }

    // Почему: до первого замера площадь нулевая, и раскладку по ней строить нельзя
    private var measured: CGSize? {
        areaSize.width > 1 && areaSize.height > 1 ? areaSize : nil
    }

    private var capacity: Int {
        guard measured != nil else { return max(store.visible.count, 1) }

        return fit(in: contentSize, preview: previewInset)
    }

    private var visiblePaneIDs: [TerminalSession.ID] {
        visiblePanes.map(\.id)
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

    // Почему: добавленные вручную папки живут рядом с сессиями и не должны вычищаться
    private var sessionFolders: Set<URL> {
        Set(store.sessions.map(\.url)).union(pinned.sources.map(\.url))
    }

    private var sessionGitRoots: Set<String> {
        Set(store.sessions.compactMap { git.snapshot(for: $0)?.root })
            .union(sessionFolders.map { InspectorState.key(for: $0) })
            .union(pinned.sources.map(\.path))
    }

    private var pinnedPaths: [String] {
        pinned.sources.map(\.path)
    }

    // Почему: ревью и рибоны должны видеть все репозитории инспектора, а не только активный
    private var pinnedGitSnapshots: [(name: String, snapshot: GitSnapshot)] {
        pinned.sources.compactMap { source in
            guard
                let snapshot = git.snapshot(path: source.path),
                snapshot.root != gitSnapshot?.root
            else { return nil }

            return (source.name, snapshot)
        }
    }

    private var pinnedBranchSnapshots: [String: GitBranchSnapshot] {
        var result: [String: GitBranchSnapshot] = [:]

        for source in pinned.sources {
            guard let snapshot = branchStore.snapshot(path: source.path) else { continue }

            result[source.path] = snapshot
        }

        return result
    }

    private var fileGroups: [FileTreeGroup] {
        pinned.sources.map { source in
            FileTreeGroup(
                id: source.id,
                title: source.name,
                model: inspector.fileTree(for: source.url),
                onRemove: { pinned.remove(source.id) }
            )
        }
    }

    private var branchGroups: [BranchTreeGroup] {
        pinned.sources.map { source in
            BranchTreeGroup(
                id: source.id,
                title: source.name,
                root: pinnedBranchSnapshots[source.path]?.root ?? source.path,
                model: inspector.branchTree(for: source.path),
                onRemove: { pinned.remove(source.id) }
            )
        }
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
        previewWidth(in: contentSize)
    }

    private var previewInset: CGFloat {
        previewInset(in: contentSize)
    }

    private var previewMode: PreviewMode {
        WorkspaceGeometry.previewMode(hasPreview: navigator.current != nil, size: contentSize)
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
    private var pinned = PinnedSourceStore()

    @State
    private var renameTarget: TerminalSession?

    @State
    private var renameText = ""

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
    private var dragged: TerminalSession.ID?

    @State
    private var dragTarget: TerminalSession.ID?

    @State
    private var areaSize = CGSize.zero

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

    @State
    private var snapshots = TerminalSnapshots()

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
                .environment(\.previewNotes, PreviewNoteSender(send: sendPreviewNote))

            rightPanel
        }
        .overlay(alignment: .topLeading) { toggle }
        .background(TrafficLights(isHidden: !isSidebarExpanded).frame(width: 0, height: 0))
        .ignoresSafeArea()
        .background(WindowBackground().ignoresSafeArea())
        .frame(minWidth: 880, minHeight: 520)
        // Почему: без терминалов фокусировать нечего, а команды меню нужны и в пустом окне
        .focusedSceneValue(\.workspaceCommands, .make(
            toggleSidebar: toggleSidebar, selectFilesMode: inspectorControls.select,
            session: selectedSession, store: store,
            selection: $selection, closeSession: liveSessions.requestClose,
            openReview: { navigator.openReview(.git) }
        ))
        .alert(
            "Переименовать терминал",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField("Имя", text: $renameText)
            Button("Отмена", role: .cancel) { renameTarget = nil }
            Button("Готово") { commitRename() }
        }
        .task { selectFirstIfNeeded() }
        .task(id: visiblePaneIDs) { await refreshPanes() }
        .task(id: selection) { await branchStore.refresh(selectedSession) }
        .task(id: pinnedPaths) { await refreshPinnedBranches() }
        .task(id: pinnedPaths) { await refreshPinnedStatus() }
        .task(id: pinnedPaths) { openPinnedTrees() }
        .onChange(of: pinnedBranchSnapshots, initial: true) { _, snapshots in
            for (path, snapshot) in snapshots {
                inspector.branchTree(for: path).apply(snapshot)
            }
        }
        .task(id: selectedSession?.url) { await settleDirectoryChange() }
        .onChange(of: selection) { old, new in activate(new, replacing: old) }
        .onChange(of: knownSessionIDs) { _, known in
            liveSessions.reconcile(known)
            snapshots.forget(known)
            navigators.prune(roots: Set(store.roots.map(\.id)))
        }
        .onChange(of: capacity) { _, room in
            guard measured != nil else { return }

            withAnimation(.smooth(duration: 0.22)) {
                store.limit(to: room, keeping: selection)
            }
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
                in: CGSize(
                    width: proxy.size.width + (isVertical ? 0 : previewInset),
                    height: proxy.size.height + (isVertical ? previewInset : 0)
                )
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
        // Почему: на высоком окне полоса ложится снизу, на широком — справа
        Group {
            if isVertical {
                VStack(spacing: WorkspaceLayout.inset) { mainContent
                    strip
                }
            } else {
                HStack(spacing: WorkspaceLayout.inset) { mainContent
                    strip
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { areaSize = $0 }
    }

    @ViewBuilder
    private var strip: some View {
        if needsStrip {
            TerminalStrip(
                sessions: store.sessions,
                shown: Set(store.visible),
                selection: selection,
                isVertical: isVertical,
                snapshots: snapshots,
                onOpen: { selection = $0.id }
            )
            .transition(.opacity)
        }
    }

    private var mainContent: some View {
        area
    }

    private var area: some View {
        ZStack {
            panes
                .padding(isVertical ? .bottom : .trailing, previewInset)

            if let entry = navigator.current { preview(entry) }
        }
    }

    private let store = SessionStore.shared
    private let terminal: TerminalBuilder<Terminal>

    public init(@ViewBuilder terminal: @escaping TerminalBuilder<Terminal>) {
        self.terminal = terminal
    }

    private func preview(_ entry: PreviewEntry) -> some View {
        let side = previewMode == .split ? previewWidth : nil
        let inset = previewMode == .split
            ? WorkspaceGeometry.expandedHeaderLeading
            : WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded)

        return previewLayer(entry, leadingInset: inset)
            .frame(width: isVertical ? nil : side, height: isVertical ? side : nil)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: isVertical ? .bottom : .trailing
            )
            .transition(
                WorkspaceGeometry.previewTransition(for: previewMode, isVertical: isVertical)
            )
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

    // Почему: карточки перечитывают файлы того репозитория, чьё ревью открыто
    func reviewRevision(_ kind: ReviewKind) -> String {
        switch kind {
        case .git:
            ([inspectorGitRoot] + pinnedGitSnapshots.map(\.snapshot.root))
                .map { "\(git.revision(forRoot: $0))" }
                .joined(separator: "|")
        case let .branch(root, ref, _, isCurrent):
            "\(git.revision(forRoot: root))|" +
                "\(branchReviews.revision(root: root, branch: ref, isCurrent: isCurrent))"
        }
    }

    // Почему: терминал занимает свободную колонку, а без места подменяет прежний активный
    func activate(_ session: TerminalSession.ID?, replacing previous: TerminalSession.ID?) {
        guard let session else { return }

        withAnimation(.smooth(duration: 0.22)) {
            store.show(session, capacity: capacity, replacing: previous)
        }

        liveSessions.activate(session)
    }

    // Почему: сохранённая область должна вернуться целиком, а не одной выбранной колонкой
    func restoreShownPanes() {
        for id in store.visible where !live.contains(id) {
            liveSessions.activate(id)
        }

        guard let selection else { return }

        liveSessions.activate(selection)
    }

    func fit(in size: CGSize, preview: CGFloat) -> Int {
        let along = isVertical ? size.height : size.width
        let minimum = isVertical
            ? WorkspaceLayout.minimumTerminalHeight
            : WorkspaceLayout.minimumTerminalWidth

        return WorkspaceGeometry.fit(room: along - preview, minimum: minimum)
    }

    // Почему: превью — такая же колонка, как терминал, но не отбирает у него минимум
    func previewWidth(in size: CGSize) -> CGFloat {
        let along = isVertical ? size.height : size.width
        let terminal = isVertical
            ? WorkspaceLayout.minimumTerminalHeight
            : WorkspaceLayout.minimumTerminalWidth
        // Почему: доля считается по составу области, а не по видимым панелям — те зависят от неё
        let panes = min(
            WorkspaceGeometry.fit(room: along, minimum: terminal),
            max(store.shown.count, 1)
        )
        let columns = CGFloat(panes + 1)
        let share = along / columns - WorkspaceLayout.inset
        let minimum = isVertical
            ? WorkspaceLayout.minimumPreviewHeight
            : WorkspaceLayout.minimumPreviewWidth
        let spare = along - terminal - WorkspaceLayout.inset

        return min(max(share, minimum), max(spare, minimum)).rounded()
    }

    func previewInset(in size: CGSize) -> CGFloat {
        let mode = WorkspaceGeometry.previewMode(hasPreview: navigator.current != nil, size: size)

        return mode == .split ? previewWidth(in: size) + WorkspaceLayout.inset : 0
    }

    func hide(_ session: TerminalSession) {
        withAnimation(.smooth(duration: 0.22)) { store.hide(session.id, capacity: capacity) }

        guard selection == session.id else { return }

        selection = visiblePanes.last?.id
    }

    func refreshBranches(for mode: FilePanelMode?) {
        guard mode == .git else { return }

        Task { await branchStore.refresh(selectedSession) }
    }

    func pollCommits() async {
        while !Task.isCancelled {
            await commits.refresh(
                root: gitSnapshot?.root,
                branch: gitSnapshot?.branch,
                isClean: gitSnapshot?.changes.isEmpty == true
            )

            await refreshPinnedStatus()

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
                if isLeading {
                    header(session, isFocused: isFocused)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !isLeading, isFocused { floatingMenu(session) }
            }
            .modifier(WorkspaceCard())
            // Почему: тянем за невидимую рамку карточки, чтобы не занимать место лишней ручкой
            .overlay {
                RoundedRectangle(cornerRadius: WorkspaceLayout.cardRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.001), lineWidth: WorkspaceLayout.dragBorder)
                    .onDrag { dragItem(for: session) }
            }
            .overlay {
                if dragTarget == session.id {
                    RoundedRectangle(
                        cornerRadius: WorkspaceLayout.cardRadius,
                        style: .continuous
                    )
                    .strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 2)
                }
            }
            .onDrop(
                of: [.text],
                delegate: PaneDropDelegate(
                    target: session.id,
                    dragged: $dragged,
                    highlighted: $dragTarget,
                    swap: movePane
                )
            )
    }

    func movePane(_ moved: TerminalSession.ID, _ target: TerminalSession.ID) {
        withAnimation(.smooth(duration: 0.22)) {
            store.move(moved, before: target)
        }
    }

    func floatingMenu(_ session: TerminalSession) -> some View {
        TerminalActionsMenu(
            rename: { startRename(session) },
            hide: { hide(session) },
            newTerminal: { addSession(at: session.url) },
            close: { liveSessions.requestClose(session) }
        )
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    func header(_ session: TerminalSession, isFocused: Bool) -> some View {
        TerminalHeader(
            session: session,
            status: git.status(for: session),
            leadingInset: WorkspaceGeometry.headerLeading(sidebarExpanded: isSidebarExpanded),
            filesMode: filesMode,
            isBusy: branchStore.isOperating(session) || isWorkingTreeBusy,
            isFocused: isFocused,
            selectAll: { selectFiles(.all, in: session) },
            selectGit: { selectFiles(.git, in: session) },
            stashChanges: { requestWorkingTree(.stash, for: session) },
            discardChanges: { requestWorkingTree(.discard, for: session) },
            rename: { startRename(session) },
            hide: { hide(session) },
            newTerminal: { addSession(at: session.url) },
            close: { liveSessions.requestClose(session) }
        )
    }

    func startRename(_ session: TerminalSession) {
        renameText = session.displayName
        renameTarget = session
    }

    func commitRename() {
        guard let renameTarget else { return }

        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setTitle(trimmed.isEmpty ? nil : trimmed, for: renameTarget.id)
        self.renameTarget = nil
    }

    // Почему: обратный слэш переносит строку и в шелле, и в агентских CLI — правки не слипаются
    func sendPreviewNote(_ note: PreviewNote) {
        dispatcher.insert(note.message(relativeTo: inspectorGitRoot) + "\\\n", into: selection)
    }

    func dragItem(for session: TerminalSession) -> NSItemProvider {
        dragged = session.id

        return NSItemProvider(object: session.id.uuidString as NSString)
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
                onFocused: { selection = session.id },
                onSnapshot: { snapshots.set($0, for: session.id) },
                wantsSnapshots: needsStrip
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
            fileGroups: fileGroups,
            branchGroups: branchGroups,
            onAdd: addPinnedSource,
            changeTreeModel: inspector.changeTree(for: gitRoot),
            branchTreeModel: inspector.branchTree(for: gitRoot),
            branchActions: branchActions,
            onOpenBranch: openBranchReview,
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
            var files: [ReviewFile] = []

            if let snapshot = gitSnapshot {
                files = ReviewFiles.build(
                    root: snapshot.root,
                    changes: snapshot.changes,
                    commits: commits.commits(for: snapshot.root),
                    repository: nil
                )
            }

            for entry in pinnedGitSnapshots {
                files += ReviewFiles.build(
                    root: entry.snapshot.root,
                    changes: entry.snapshot.changes,
                    commits: commits.commits(for: entry.snapshot.root),
                    repository: entry.name
                )
            }

            return files

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

    // Почему: одна область — ряд или столбец равных долей, вложенных разбиений больше нет
    func paneFrames(in size: CGSize) -> [TerminalSession.ID: CGRect] {
        let panes = visiblePanes
        guard !panes.isEmpty else { return [:] }

        let gap = WorkspaceLayout.inset
        let along = isVertical ? size.height : size.width
        let share = max((along - gap * CGFloat(panes.count - 1)) / CGFloat(panes.count), 1)
        var frames: [TerminalSession.ID: CGRect] = [:]

        for (index, session) in panes.enumerated() {
            let offset = (share + gap) * CGFloat(index)

            frames[session.id] = isVertical
                ? CGRect(x: 0, y: offset, width: size.width, height: share)
                : CGRect(x: offset, y: 0, width: share, height: size.height)
        }

        return frames
    }

    func restingFrames(in area: CGSize) -> [TerminalSession.ID: CGRect] {
        var frames: [TerminalSession.ID: CGRect] = [:]

        for session in store.sessions where !store.shown.contains(session.id) {
            frames[session.id] = CGRect(origin: .zero, size: area)
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

        openPinnedTrees()
    }

    // Почему: добавленные папки живут своим деревом и не зависят от активного терминала
    func openPinnedTrees() {
        for source in pinned.sources {
            inspector.fileTree(for: source.url).open(
                source.url,
                gitDirectories: [],
                onGitChange: {}
            )
        }
    }

    func refreshPinnedBranches() async {
        for path in pinnedPaths {
            await branchStore.refresh(root: path)
        }
    }

    func refreshPinnedStatus() async {
        for path in pinnedPaths {
            await git.refresh(path: path)
        }

        await refreshPinnedCommits()
    }

    func refreshPinnedCommits() async {
        for entry in pinnedGitSnapshots {
            await commits.refresh(
                root: entry.snapshot.root,
                branch: entry.snapshot.branch,
                isClean: entry.snapshot.changes.isEmpty
            )
        }
    }

    func addPinnedSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Добавить"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        pinned.add(url)
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
        if selection == nil {
            selection = store.session(for: store.selectedSessionID)?.id ?? store.sessions.first?.id
        }

        restoreShownPanes()
    }
}
