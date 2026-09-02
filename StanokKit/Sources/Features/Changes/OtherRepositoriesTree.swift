import SwiftUI

struct OtherRepositoriesTree: View {

    @ViewBuilder
    private var content: some View {
        if !shown.isEmpty {
            SectionHeader(title: "Изменения в других репозиториях")

            ForEach(shown) { repository in
                row(repository)

                if opened.contains(repository.root) {
                    BranchTree(
                        model: inspector.branchTree(for: repository.root),
                        actions: nil,
                        tracking: .none,
                        root: repository.root,
                        counters: counters(repository),
                        onOpenBranch: onOpenBranch
                    )
                }
            }
        }
    }

    var body: some View {
        content
            .task(id: others.map(\.root).joined(separator: "\n")) { await loadAll() }
    }

    let model: TouchedRepositoriesModel
    let inspector: InspectorState
    let branches: GitBranchStore
    let active: String?
    let onOpenBranch: (String, GitBranchRef) -> Void

    @State
    private var opened: Set<String> = []

    // Почему: репозиторий активного терминала уже показан секцией веток выше
    private var others: [TouchedRepository] {
        model.repositories.filter { $0.root != active }
    }

    // Почему: пустая папка ни о чём не говорит, показываем только репозитории с ветками
    private var shown: [TouchedRepository] {
        others.filter { branches.snapshot(root: $0.root)?.refs.isEmpty == false }
    }

    private func counters(_ repository: TouchedRepository) -> String? {
        let count = repository.changes.count
        guard count > 0 else { return nil }

        return "\(count) \(PluralForm.of(count, "файл", "файла", "файлов"))"
    }

    private func row(_ repository: TouchedRepository) -> some View {
        FileRow(
            name: repository.name,
            url: URL(filePath: repository.root),
            isDirectory: true,
            isExpanded: opened.contains(repository.root),
            depth: 1,
            status: nil,
            isSelected: false,
            actions: nil
        )
        .help(repository.root)
        .onTapGesture { toggle(repository.root) }
    }

    private func toggle(_ root: String) {
        withAnimation(.smooth(duration: 0.2)) {
            if opened.contains(root) { opened.remove(root) } else { opened.insert(root) }
        }
    }

    private func loadAll() async {
        for repository in others {
            guard !Task.isCancelled else { return }

            await load(repository.root)
        }
    }

    private func load(_ root: String) async {
        await branches.refresh(root: root)
        inspector.branchTree(for: root).apply(branches.snapshot(root: root))
    }
}
