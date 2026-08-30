import SwiftUI

struct FileRow: View {

    @ViewBuilder
    private var chevron: some View {
        if node.isDirectory {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                .frame(width: 10)
        } else {
            Color.clear.frame(width: 10)
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            RowAction(
                icon: "doc.badge.plus",
                hint: "Новый файл",
                isVisible: isHovering,
                action: newFile
            )

            RowAction(icon: "pencil", hint: "Переименовать", isVisible: isHovering, action: rename)

            RowAction(icon: "trash", hint: "Удалить", isVisible: isHovering, action: delete)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            chevron

            Image(nsImage: FileIcons.icon(for: node.url, isDirectory: node.isDirectory))
                .resizable()
                .frame(width: 15, height: 15)

            Text(node.name)
                .font(Typography.row)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            actions
        }
        .padding(.leading, 8 + CGFloat(node.depth - 1) * 13)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(
            isSelected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 8, style: .continuous)
        )
        .contentShape(.rect(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
    }

    let node: FileNode

    let isSelected: Bool

    let newFile: () -> Void

    let rename: () -> Void

    let delete: () -> Void

    @State
    private var isHovering = false

}
