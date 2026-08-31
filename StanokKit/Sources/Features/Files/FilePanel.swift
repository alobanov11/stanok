import SwiftUI

struct FilePanel: View {

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Файлы")
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

        case .changes:
            ChangeTree(model: changeTreeModel, selected: $selected, onOpen: onOpen)
        }
    }

    let mode: FilePanelMode

    let fileTreeModel: FileTreeModel

    let changeTreeModel: ChangeTreeModel

    let snapshot: GitSnapshot?

    @Binding
    var selected: URL?

    let onOpen: (URL) -> Void

}
