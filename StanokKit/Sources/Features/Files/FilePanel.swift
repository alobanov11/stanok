import SwiftUI

struct FilePanel: View {

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        mode == .all ? "Файлы" : "Git"
    }

    private var counters: String? {
        guard let snapshot, !snapshot.changes.isEmpty else { return nil }

        return "+\(snapshot.added) −\(snapshot.removed)"
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: WorkspaceLayout.headerHeight)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .all:
            FileTree(model: fileTreeModel, snapshot: snapshot, selected: $selected, onOpen: onOpen)

        case .git:
            git
        }
    }

    private var git: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                BranchTree(
                    model: branchTreeModel,
                    actions: branchActions,
                    tracking: snapshot?.tracking ?? .none,
                    root: snapshot?.root,
                    counters: counters,
                    onOpenBranch: onOpenBranch
                )

                ChangeTree(
                    model: changeTreeModel,
                    selected: $selected,
                    onOpen: onOpen,
                    onReview: hasGitReview ? { onReview(.git) } : nil
                )

            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    let mode: FilePanelMode
    let fileTreeModel: FileTreeModel
    let changeTreeModel: ChangeTreeModel
    let branchTreeModel: BranchTreeModel
    let branchActions: BranchActions
    let onOpenBranch: (String, GitBranchRef) -> Void
    let snapshot: GitSnapshot?

    @Binding
    var selected: URL?

    let onOpen: (URL) -> Void
    let hasGitReview: Bool
    let onReview: (ReviewKind) -> Void
}
