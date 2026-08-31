import SwiftUI

struct BranchTree: View {

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            searchField
            content
        }
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

    private var toolbar: some View {
        HStack(spacing: 2) {
            RowAction(
                icon: "plus",
                hint: "Создать ветку от HEAD",
                isVisible: true,
                action: { newBranchName = ""
                    isPromptingNewBranch = true
                }
            )
            .disabled(actions.isOperating)

            Spacer(minLength: 0)

            RowAction(
                icon: "arrow.triangle.2.circlepath",
                hint: "git fetch --all --prune — выполнится в терминале",
                isVisible: true,
                action: actions.fetch
            )

            RowAction(
                icon: "arrow.down.circle",
                hint: "git pull --ff-only — выполнится в терминале",
                isVisible: true,
                action: actions.pull
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            TextField("Поиск веток", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(Typography.row)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        if !model.isLoaded {
            placeholder("Загрузка веток…")
        } else if model.isEmpty {
            placeholder("Нет веток")
        } else if hasNoMatches {
            placeholder("Ничего не найдено")
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let listError = model.listError { errorBanner(listError) }

                SectionHeader(title: "Branches")
                ForEach(model.localMatches) { row($0) }

                SectionHeader(title: "Remotes")
                remotesCaption

                ForEach(model.remoteGroups) { group in
                    remoteGroupHeader(group.name)
                    ForEach(group.refs) { row($0) }
                }

                if let worktreeError = model.worktreeError { errorBanner(worktreeError) }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .opacity(actions.isOperating ? 0.6 : 1)
        .allowsHitTesting(!actions.isOperating)
    }

    private var remotesCaption: some View {
        Text("Локальный слепок, может быть устаревшим")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
    }

    private var hasNoMatches: Bool {
        !model.searchText.isEmpty && model.localMatches.isEmpty && model.remoteGroups.isEmpty
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
    var model: BranchListModel

    let actions: BranchActions

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

    private func remoteGroupHeader(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }

    private func row(_ ref: GitBranchRef) -> some View {
        FileRow(
            name: ref.displayName,
            url: URL(fileURLWithPath: "/" + ref.fullName),
            isDirectory: false,
            isExpanded: false,
            depth: 1,
            status: nil,
            isSelected: ref.isCurrent,
            actions: rowActions(ref),
            icon: icon(for: ref)
        )
        .opacity(ref.occupyingWorktreePath != nil ? 0.5 : 1)
        .help(helpText(for: ref))
        .onTapGesture { Task { await handleTap(ref) } }
    }

    private func rowActions(_ ref: GitBranchRef) -> FileRow.Actions? {
        guard ref.kind == .local, !ref.isCurrent, ref.occupyingWorktreePath == nil else {
            return nil
        }

        return FileRow.Actions(items: [
            .init(icon: "trash", hint: "Удалить ветку", action: { deleteTarget = ref })
        ])
    }

    private func icon(for ref: GitBranchRef) -> Image {
        if ref.occupyingWorktreePath != nil { return Image(systemName: "lock.fill") }
        if ref.isCurrent { return Image(systemName: "checkmark.circle.fill") }

        return Image(systemName: "arrow.trianglehead.branch")
    }

    private func helpText(for ref: GitBranchRef) -> String {
        if let path = ref.occupyingWorktreePath {
            return "Занято в другом worktree: \(path)"
        }

        if ref.isCurrent { return "Текущая ветка" }

        if ref.kind == .remote {
            return "Создать локальную ветку «\(ref.displayName)» и переключиться"
        }

        return "Переключиться на «\(ref.displayName)»"
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
