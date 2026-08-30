import SwiftUI

struct FileRow: View {

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

            Spacer(minLength: 0)
        }
        .padding(.leading, 8 + CGFloat(node.depth - 1) * 13)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(
            isSelected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 8, style: .continuous)
        )
        .contentShape(.rect(cornerRadius: 8))
    }

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

    let node: FileNode

    let isSelected: Bool

}
