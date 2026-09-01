import SwiftUI

struct BranchTree: View {

    var body: some View {
        content
            .alert("Новая ветка", isPresented: $isPromptingNewBranch) {
                TextField("Имя ветки", text: $newBranchName)
                Button("Отмена", role: .cancel) {}
                Button("Создать") { submitNewBranch() }
            }
            .alert("Удалить ветку?", isPresented: isDeleting, presenting: deleteTarget) { ref in
                Button("Отмена", role: .cancel) {}
                Button("Удалить", role: .destructive) { Task { await performDelete(ref) } }
            } message: { ref in
                Text("«\(ref.displayName)» удалится, только если она уже слита в текущую.")
            }
            .alert(
                "В рабочей копии есть изменения",
                isPresented: isConfirmingDirtySwitch,
                presenting: dirtyTarget
            ) { ref in
                Button("Отмена", role: .cancel) {}
                Button("Всё равно переключиться") { Task { await performSwitch(ref) } }
            } message: { _ in
                Text("Git попробует перенести изменения на новую ветку или откажет при конфликте.")
            }
            .alert(
                "Создать локальную ветку и переключиться?",
                isPresented: isConfirmingCreate,
                presenting: createTarget
            ) { ref in
                Button("Отмена", role: .cancel) {}
                Button("Создать и переключиться") { Task { await performSwitch(ref) } }
            } message: { ref in
                Text(createMessage(for: ref))
            }
            .alert("Не получилось", isPresented: isFailing) {
                Button("Ок") {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if case .loaded = model.state, let root = model.root {
            SectionHeader(title: "Ветки")

            list(root)
        }
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    private var isConfirmingDirtySwitch: Binding<Bool> {
        Binding(get: { dirtyTarget != nil }, set: { if !$0 { dirtyTarget = nil } })
    }

    private var isConfirmingCreate: Binding<Bool> {
        Binding(get: { createTarget != nil }, set: { if !$0 { createTarget = nil } })
    }

    private var isFailing: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    @Bindable
    var model: BranchTreeModel

    let actions: BranchActions?
    let tracking: GitTracking
    let root: String?
    let commits: BranchCommitStore
    let onReviewCommit: (String, GitCommitChanges) -> Void

    @State
    private var isPromptingNewBranch = false

    @State
    private var isTapping = false

    @State
    private var newBranchName = ""

    @State
    private var deleteTarget: GitBranchRef?

    @State
    private var dirtyTarget: GitBranchRef?

    @State
    private var createTarget: GitBranchRef?

    @State
    private var errorMessage: String?

    @State
    private var opened: Set<String> = []
}

private extension BranchTree {

    @ViewBuilder
    func list(_ root: BranchNode) -> some View {
        if let listError = model.listError { errorBanner(listError) }

        ForEach(root.visibleDescendants) { row($0) }
            .opacity(actions?.isOperating == true ? 0.6 : 1)
            .allowsHitTesting(actions?.isOperating != true)

        if let worktreeError = model.worktreeError { errorBanner(worktreeError) }
    }

    func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func row(_ node: BranchNode) -> some View {
        if let ref = node.ref {
            leafRow(node, ref: ref)
        } else {
            folderRow(node)
        }
    }

    func folderRow(_ node: BranchNode) -> some View {
        FileRow(
            name: node.name,
            isDirectory: true,
            isExpanded: node.isExpanded,
            depth: node.depth,
            status: nil,
            isSelected: false,
            actions: folderActions(node),
            icon: Image(systemName: "folder")
        )
        .onTapGesture { withAnimation(.smooth(duration: 0.2)) { node.toggle() } }
    }

    @ViewBuilder
    func leafRow(_ node: BranchNode, ref: GitBranchRef) -> some View {
        let key = (root ?? "") + "\n" + ref.fullName
        let isOpen = opened.contains(key)

        FileRow(
            name: node.name,
            isDirectory: true,
            isExpanded: isOpen,
            depth: node.depth,
            status: nil,
            isSelected: ref.isCurrent,
            actions: leafActions(ref),
            trailing: divergence(for: ref),
            icon: leafIcon(for: ref)
        )
        .opacity(ref.occupyingWorktreePath != nil ? 0.5 : 1)
        .help(helpText(for: ref))
        .onTapGesture(count: 2) { Task { await handleTap(ref) } }
        .onTapGesture { toggle(ref) }
        .task(id: isOpen ? key : "") { await loadCommits(ref, isOpen: isOpen) }

        if isOpen {
            ForEach(commits.commits(root: root ?? "", branch: ref.fullName), id: \.sha) { commit in
                commitRow(commit, depth: node.depth + 1)
            }
        }
    }

    func commitRow(_ commit: GitCommitChanges, depth: Int) -> some View {
        FileRow(
            name: commit.title,
            isDirectory: false,
            isExpanded: false,
            depth: depth,
            status: nil,
            isSelected: false,
            actions: nil,
            icon: Image(systemName: "point.3.connected.trianglepath.dotted")
        )
        .help("Двойной клик — ревью коммита")
        .onTapGesture(count: 2) { onReviewCommit(root ?? "", commit) }
    }

    func toggle(_ ref: GitBranchRef) {
        let key = (root ?? "") + "\n" + ref.fullName

        withAnimation(.smooth(duration: 0.2)) {
            if opened.contains(key) { opened.remove(key) } else { opened.insert(key) }
        }
    }

    func loadCommits(_ ref: GitBranchRef, isOpen: Bool) async {
        guard isOpen, let root else { return }

        await commits.load(root: root, branch: ref.fullName)
    }

    func divergence(for ref: GitBranchRef) -> String? {
        guard ref.isCurrent, tracking.hasDivergence else { return nil }

        let parts = [
            tracking.ahead > 0 ? "\(tracking.ahead)↑" : nil,
            tracking.behind > 0 ? "\(tracking.behind)↓" : nil
        ]

        return parts.compactMap(\.self).joined(separator: " ")
    }

    func folderActions(_ node: BranchNode) -> FileRow.Actions? {
        guard actions != nil else { return nil }

        if node.id == BranchTreeBuilder.remotesID {
            return FileRow.Actions(items: [
                .init(
                    icon: "arrow.triangle.2.circlepath",
                    hint: "git fetch --all --prune — выполнится в терминале",
                    action: { actions?.fetch() }
                )
            ])
        }

        let prefix = branchPrefix(for: node)
        return FileRow.Actions(items: [
            .init(
                icon: "plus",
                hint: createHint(prefix: prefix),
                action: { beginCreate(prefix: prefix) }
            )
        ])
    }

    func leafActions(_ ref: GitBranchRef) -> FileRow.Actions? {
        guard actions != nil, ref.occupyingWorktreePath == nil else { return nil }

        if ref.isCurrent {
            return FileRow.Actions(items: [
                .init(
                    icon: "arrow.down.circle",
                    hint: "git pull --ff-only — выполнится в терминале",
                    action: { actions?.pull() }
                )
            ])
        }

        guard ref.kind == .local else { return nil }

        return FileRow.Actions(items: [
            .init(icon: "trash", hint: "Удалить ветку", action: { deleteTarget = ref })
        ])
    }

    func leafIcon(for ref: GitBranchRef) -> Image {
        if ref.occupyingWorktreePath != nil { return Image(systemName: "lock.fill") }
        if ref.isCurrent { return Image(systemName: "checkmark.circle.fill") }

        return Image(systemName: "arrow.trianglehead.branch")
    }

    func branchPrefix(for node: BranchNode) -> String {
        let parts = node.id.split(separator: "/").map(String.init)

        guard let head = parts.first else { return "" }

        return head == BranchTreeBuilder.remotesID
            ? parts.dropFirst(2).joined(separator: "/")
            : parts.dropFirst().joined(separator: "/")
    }

    func createHint(prefix: String) -> String {
        prefix.isEmpty ? "Создать ветку от HEAD" : "Создать ветку «\(prefix)/…»"
    }

    func beginCreate(prefix: String) {
        newBranchName = prefix.isEmpty ? "" : "\(prefix)/"
        isPromptingNewBranch = true
    }

    func helpText(for ref: GitBranchRef) -> String {
        if let path = ref.occupyingWorktreePath {
            return "Занято в другом worktree: \(path)"
        }

        if ref.isCurrent { return "Текущая ветка" }

        if ref.kind == .remote {
            return "Двойной клик — создать локальную ветку «\(ref.displayName)» и переключиться"
        }

        return "Двойной клик — переключиться на «\(ref.displayName)»"
    }

    func createMessage(for ref: GitBranchRef) -> String {
        let source = ref.remoteName.map { "\($0)/\(ref.displayName)" } ?? ref.displayName

        return "Локальная ветка «\(ref.displayName)» будет создана из «\(source)», и рабочая"
            + " копия переключится на неё. Незакоммиченные изменения git перенесёт"
            + " или откажет при конфликте."
    }

    func handleTap(_ ref: GitBranchRef) async {
        guard actions != nil else { return }

        guard
            actions?.isOperating != true,
            !isTapping,
            !ref.isCurrent,
            ref.occupyingWorktreePath == nil
        else { return }

        isTapping = true

        defer { isTapping = false }

        if ref.kind == .remote {
            createTarget = ref
            return
        }

        guard let actions else { return }

        switch await actions.checkDirty() {
        case .dirty:
            dirtyTarget = ref
            return

        case .unknown:
            errorMessage = "Не удалось проверить рабочую копию"
            return

        case .clean:
            break
        }

        await performSwitch(ref)
    }

    func performSwitch(_ ref: GitBranchRef) async {
        guard let actions else { return }

        let outcome = await actions.switchTo(ref)
        if !outcome.succeeded { errorMessage = outcome.message }
    }

    func performDelete(_ ref: GitBranchRef) async {
        guard let actions else { return }

        let outcome = await actions.delete(ref.displayName)
        if !outcome.succeeded { errorMessage = outcome.message }
    }

    func submitNewBranch() {
        let trimmed = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            guard let actions else { return }

            let format = await actions.checkRefFormat(trimmed)
            guard format.succeeded else {
                errorMessage = format.message
                return
            }

            let outcome = await actions.create(trimmed)
            if !outcome.succeeded { errorMessage = outcome.message }
        }
    }
}
