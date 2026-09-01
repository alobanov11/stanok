import SwiftUI

struct OtherRepositoriesTree: View {

    @ViewBuilder
    private var content: some View {
        if !others.isEmpty {
            SectionHeader(title: "Изменения в других репозиториях")

            ForEach(others) { repository in
                row(repository)

                if opened.contains(repository.root) {
                    BranchTree(
                        model: inspector.branchTree(for: repository.root),
                        actions: nil,
                        tracking: .none,
                        root: repository.root,
                        commits: commits,
                        onReviewCommit: onReviewCommit
                    )
                    .task(id: repository.root) { await load(repository.root) }
                }
            }
        }
    }

    var body: some View {
        content
    }

    let model: TouchedRepositoriesModel
    let inspector: InspectorState
    let branches: GitBranchStore
    let commits: BranchCommitStore
    let active: String?
    let onReviewCommit: (String, GitCommitChanges) -> Void

    @State
    private var opened: Set<String> = []

    // Почему: репозиторий активного терминала уже показан секцией веток выше
    private var others: [TouchedRepository] {
        model.repositories.filter { $0.root != active }
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

    private func load(_ root: String) async {
        await branches.refresh(root: root)
        inspector.branchTree(for: root).apply(branches.snapshot(root: root))
    }
}
