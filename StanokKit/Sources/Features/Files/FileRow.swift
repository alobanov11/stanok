import SwiftUI

struct FileRow: View {

    struct Actions {

        let newFile: () -> Void

        let rename: () -> Void

        let delete: () -> Void
    }

    @ViewBuilder
    private var chevron: some View {
        if isDirectory {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 10)
        } else {
            Color.clear.frame(width: 10)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let status {
            Text(status.letter)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 12)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let actions {
            HStack(spacing: 0) {
                RowAction(
                    icon: "doc.badge.plus",
                    hint: "Новый файл",
                    isVisible: isHovering,
                    action: actions.newFile
                )

                RowAction(
                    icon: "pencil",
                    hint: "Переименовать",
                    isVisible: isHovering,
                    action: actions.rename
                )

                RowAction(
                    icon: "trash",
                    hint: "Удалить",
                    isVisible: isHovering,
                    action: actions.delete
                )
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            chevron

            Image(nsImage: FileIcons.icon(for: url, isDirectory: isDirectory))
                .resizable()
                .frame(width: 15, height: 15)

            Text(name)
                .font(Typography.row)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            actionButtons
            statusBadge
        }
        .padding(.leading, 8 + CGFloat(depth - 1) * 13)
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

    let name: String

    let url: URL

    let isDirectory: Bool

    let isExpanded: Bool

    let depth: Int

    let status: GitFileStatus?

    let isSelected: Bool

    let actions: Actions?

    @State
    private var isHovering = false

}
