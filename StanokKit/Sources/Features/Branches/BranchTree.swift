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
        if !model.isLoaded {
            placeholder("Загрузка веток…")
        } else if !model.isRepository {
            placeholder("Здесь нет git-репозитория")
        } else if model.isEmpty {
            placeholder("Нет веток")
        } else if let root = model.root {
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

    let actions: BranchActions
    let tracking: GitTracking

    @State
    private var isPromptingNewBranch = false

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

    private func list(_ root: BranchNode) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let listError = model.listError { errorBanner(listError) }

                ForEach(root.visibleDescendants) { row($0) }

                if let worktreeError = model.worktreeError { errorBanner(worktreeError) }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .opacity(actions.isOperating ? 0.6 : 1)
        .allowsHitTesting(!actions.isOperating)
    }

    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()

            Text(text)
                .font(Typography.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ node: BranchNode) -> some View {
        if let ref = node.ref {
            leafRow(node, ref: ref)
        } else {
            folderRow(node)
        }
    }

    private func folderRow(_ node: BranchNode) -> some View {
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

    private func leafRow(_ node: BranchNode, ref: GitBranchRef) -> some View {
        FileRow(
            name: node.name,
            isDirectory: false,
            isExpanded: false,
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
    }

    private func divergence(for ref: GitBranchRef) -> String? {
        guard ref.isCurrent, tracking.hasDivergence else { return nil }

        var text = ""
        if tracking.ahead > 0 { text += "\(tracking.ahead)↑" }
        if tracking.ahead > 0, tracking.behind > 0 { text += " " }
        if tracking.behind > 0 { text += "\(tracking.behind)↓" }

        return text
    }

    private func folderActions(_ node: BranchNode) -> FileRow.Actions? {
        if node.id == BranchTreeBuilder.remotesID {
            return FileRow.Actions(items: [
                .init(
                    icon: "arrow.triangle.2.circlepath",
                    hint: "git fetch --all --prune — выполнится в терминале",
                    action: actions.fetch
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

    private func leafActions(_ ref: GitBranchRef) -> FileRow.Actions? {
        guard ref.occupyingWorktreePath == nil else { return nil }

        if ref.isCurrent {
            return FileRow.Actions(items: [
                .init(
                    icon: "arrow.down.circle",
                    hint: "git pull --ff-only — выполнится в терминале",
                    action: actions.pull
                )
            ])
        }

        guard ref.kind == .local else { return nil }

        return FileRow.Actions(items: [
            .init(icon: "trash", hint: "Удалить ветку", action: { deleteTarget = ref })
        ])
    }

    private func leafIcon(for ref: GitBranchRef) -> Image {
        if ref.occupyingWorktreePath != nil { return Image(systemName: "lock.fill") }
        if ref.isCurrent { return Image(systemName: "checkmark.circle.fill") }

        return Image(systemName: "arrow.trianglehead.branch")
    }

    private func branchPrefix(for node: BranchNode) -> String {
        let parts = node.id.split(separator: "/").map(String.init)

        guard let head = parts.first else { return "" }

        return head == BranchTreeBuilder.remotesID
            ? parts.dropFirst(2).joined(separator: "/")
            : parts.dropFirst().joined(separator: "/")
    }

    private func createHint(prefix: String) -> String {
        prefix.isEmpty ? "Создать ветку от HEAD" : "Создать ветку «\(prefix)/…»"
    }

    private func beginCreate(prefix: String) {
        newBranchName = prefix.isEmpty ? "" : "\(prefix)/"
        isPromptingNewBranch = true
    }

    private func helpText(for ref: GitBranchRef) -> String {
        if let path = ref.occupyingWorktreePath {
            return "Занято в другом worktree: \(path)"
        }

        if ref.isCurrent { return "Текущая ветка" }

        if ref.kind == .remote {
            return "Двойной клик — создать локальную ветку «\(ref.displayName)» и переключиться"
        }

        return "Двойной клик — переключиться на «\(ref.displayName)»"
    }

    private func createMessage(for ref: GitBranchRef) -> String {
        let source = ref.remoteName.map { "\($0)/\(ref.displayName)" } ?? ref.displayName

        return "Локальная ветка «\(ref.displayName)» будет создана из «\(source)», и рабочая"
            + " копия переключится на неё. Незакоммиченные изменения git перенесёт"
            + " или откажет при конфликте."
    }

    private func handleTap(_ ref: GitBranchRef) async {
        guard !actions.isOperating, !ref.isCurrent, ref.occupyingWorktreePath == nil else {
            return
        }

        if ref.kind == .remote {
            createTarget = ref
            return
        }

        if await actions.checkDirty() == true {
            dirtyTarget = ref
            return
        }

        await performSwitch(ref)
    }

    private func performSwitch(_ ref: GitBranchRef) async {
        let outcome = await actions.switchTo(ref)
        if !outcome.succeeded { errorMessage = outcome.message }
    }

    private func performDelete(_ ref: GitBranchRef) async {
        let outcome = await actions.delete(ref.displayName)
        if !outcome.succeeded { errorMessage = outcome.message }
    }

    private func submitNewBranch() {
        let trimmed = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
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
