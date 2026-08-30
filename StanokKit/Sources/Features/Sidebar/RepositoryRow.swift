import SwiftUI

struct RepositoryRow: View {

    private var iconStyle: AnyShapeStyle {
        repository.isReachable ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange)
    }

    private var titleStyle: AnyShapeStyle {
        repository.isReachable ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    private var hint: String {
        repository.isReachable
            ? repository.url.path(percentEncoded: false)
            : "Папка недоступна — перенесена или удалена"
    }

    private var actions: some View {
        HStack(spacing: 0) {
            RowAction(
                icon: "rectangle.badge.plus",
                hint: "Новый терминал",
                isVisible: isHovering,
                action: addSession
            )

            RowAction(
                icon: "minus",
                hint: "Убрать проект из списка",
                isVisible: isHovering,
                action: remove
            )
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: repository.isReachable ? "folder" : "exclamationmark.triangle")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(iconStyle)

            Text(repository.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(titleStyle)

            Spacer(minLength: 4)

            actions

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(repository.isExpanded ? 90 : 0))
                .frame(width: 12)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .contentShape(.rect(cornerRadius: 10))
        .onTapGesture(perform: toggle)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .help(hint)
    }

    let repository: Repository

    let toggle: () -> Void

    let addSession: () -> Void

    let remove: () -> Void

    @State
    private var isHovering = false

}
