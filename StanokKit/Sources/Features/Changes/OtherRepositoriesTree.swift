import SwiftUI

struct OtherRepositoriesTree: View {

    @ViewBuilder
    private var content: some View {
        if !model.repositories.isEmpty {
            SectionHeader(title: "Изменения в других репозиториях")

            ForEach(model.repositories) { repository in
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
    let onReviewCommit: (GitCommitChanges) -> Void

    @State
    private var opened: Set<String> = []

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
