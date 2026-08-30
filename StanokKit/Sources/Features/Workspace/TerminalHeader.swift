import SwiftUI

struct TerminalHeader: View {

    private var badgeBackground: AnyShapeStyle {
        isFilesOpen ? AnyShapeStyle(.white.opacity(0.14)) : AnyShapeStyle(.white.opacity(0.05))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let repository {
                folderBadge(repository.name)
            }

            if let branch = status?.branch {
                label("arrow.trianglehead.branch", branch)
            }

            if let status, status.hasChanges {
                counters(status)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, 14)
        .frame(height: WorkspaceLayout.headerHeight)
    }

    let repository: Repository?

    let status: GitStatus?

    let leadingInset: CGFloat

    let isFilesOpen: Bool

    let toggleFiles: () -> Void

    private func folderBadge(_ name: String) -> some View {
        Button(action: toggleFiles) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "folder")

                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(Typography.heading)
            .tracking(Typography.headingTracking)
            .foregroundStyle(isFilesOpen ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeBackground, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(isFilesOpen ? "Скрыть файлы" : "Показать файлы")
    }

    private func counters(_ status: GitStatus) -> some View {
        var added = AttributedString("+\(status.added)")
        added.foregroundColor = .green

        var removed = AttributedString("−\(status.removed)")
        removed.foregroundColor = .red

        return Text(added + AttributedString("  ") + removed)
            .font(.system(size: 11))
            .monospacedDigit()
    }

    private func label(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: icon)

            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}
