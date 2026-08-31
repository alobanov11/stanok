import SwiftUI

struct ChangeTree: View {

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        if model.nodes.isEmpty {
            placeholder
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.visible) { row($0) }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var placeholder: some View {
        VStack {
            Spacer()

            Text("Нет изменений")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    let model: ChangeTreeModel

    @Binding
    var selected: URL?

    let onOpen: (URL) -> Void

    private func row(_ node: GitTreeNode) -> some View {
        FileRow(
            name: node.name,
            url: node.url,
            isDirectory: node.isDirectory,
            isExpanded: model.isExpanded(node),
            depth: node.depth,
            status: node.status,
            isSelected: node.url == selected,
            actions: nil
        )
        .onTapGesture { select(node) }
    }

    private func select(_ node: GitTreeNode) {
        guard node.isDirectory else {
            guard node.status != .deleted else { return }

            selected = node.url
            onOpen(node.url)
            return
        }

        withAnimation(.smooth(duration: 0.2)) { model.toggle(node) }
    }
}
