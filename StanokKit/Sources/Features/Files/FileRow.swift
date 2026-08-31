import SwiftUI

struct FileRow: View {

    struct Actions {

        struct Item {

            let icon: String

            let hint: String

            let action: () -> Void
        }

        let items: [Item]
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
            if isHovering {
                HStack(spacing: 0) {
                    ForEach(Array(actions.items.enumerated()), id: \.offset) { _, item in
                        RowAction(icon: item.icon, hint: item.hint, action: item.action)
                    }
                }
            } else if trailing == nil {
                Color.clear.frame(width: CGFloat(actions.items.count) * 20, height: 18)
            }
        }
    }

    @ViewBuilder
    private var trailingText: some View {
        if let trailing {
            Text(trailing)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let icon {
            icon
                .resizable()
                .frame(width: 15, height: 15)
        } else if let url {
            Image(nsImage: FileIcons.icon(for: url, isDirectory: isDirectory))
                .resizable()
                .frame(width: 15, height: 15)
        } else {
            Image(systemName: isDirectory ? "folder" : "doc")
                .resizable()
                .frame(width: 15, height: 15)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            chevron

            leadingIcon

            Text(name)
                .font(Typography.row)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            trailingText
            actionButtons
            statusBadge
        }
        .padding(.leading, 8 + CGFloat(depth - 1) * 13)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(
            isDropTarget
                ? AnyShapeStyle(Color.accentColor.opacity(0.28))
                : isSelected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 8, style: .continuous)
        )
        .contentShape(.rect(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
    }

    let name: String

    var url: URL?

    let isDirectory: Bool

    let isExpanded: Bool

    let depth: Int

    let status: GitFileStatus?

    let isSelected: Bool

    var isDropTarget = false

    let actions: Actions?

    var trailing: String?

    var icon: Image?

    @State
    private var isHovering = false

}
