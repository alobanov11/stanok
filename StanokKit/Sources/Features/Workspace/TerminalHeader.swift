import SwiftUI

struct TerminalHeader: View {

    private var badgeBackground: AnyShapeStyle {
        filesMode == .all
            ? AnyShapeStyle(.white.opacity(0.14))
            : AnyShapeStyle(.white.opacity(0.05))
    }

    private var branchBackground: AnyShapeStyle {
        filesMode == .branches
            ? AnyShapeStyle(.white.opacity(0.14))
            : AnyShapeStyle(.white.opacity(0.05))
    }

    private var changesBackground: AnyShapeStyle {
        filesMode == .changes
            ? AnyShapeStyle(.white.opacity(0.14))
            : AnyShapeStyle(.white.opacity(0.05))
    }

    private var hasChanges: Bool {
        status?.hasChanges ?? false
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let repository {
                folderBadge(repository.name)
            }

            if let branch = status?.branch {
                branchBadge(branch)
                changesBadge()
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

    let filesMode: FilePanelMode?

    let selectAll: () -> Void

    let selectChanges: () -> Void

    let selectBranches: () -> Void

    let stashChanges: () -> Void

    let discardChanges: () -> Void

    let isBusy: Bool

    private func folderBadge(_ name: String) -> some View {
        Button(action: selectAll) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "folder")

                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(Typography.heading)
            .tracking(Typography.headingTracking)
            .foregroundStyle(
                filesMode == .all ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeBackground, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(filesMode == .all ? "Скрыть файлы" : "Показать файлы")
    }

    private func branchBadge(_ branch: String) -> some View {
        Button(action: selectBranches) {
            busyLabel(branch)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(branchBackground, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(filesMode == .branches ? "Скрыть ветки" : "Показать ветки")
    }

    private func changesBadge() -> some View {
        Button(action: selectChanges) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "plusminus")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if let status, status.hasChanges {
                    counters(status)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(changesBackground, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(filesMode == .changes ? "Скрыть изменения" : "Показать изменения")
        .contextMenu {
            Button(WorkingTreeAction.stash.command, action: stashChanges)
                .disabled(!hasChanges)

            Button(
                WorkingTreeAction.discard.command,
                role: .destructive,
                action: discardChanges
            )
            .disabled(!hasChanges)
        }
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

    @ViewBuilder
    private func busyLabel(_ branch: String) -> some View {
        if isBusy {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 11, height: 11)

                Text(branch)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.system(size: 11))
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                label("arrow.trianglehead.branch", branch)

                if let tracking = status?.tracking, tracking.hasDivergence {
                    divergence(tracking)
                }
            }
        }
    }

    private func divergence(_ tracking: GitTracking) -> some View {
        var text = AttributedString()
        if tracking.ahead > 0 { text += AttributedString("\(tracking.ahead)↑") }
        if tracking.ahead > 0, tracking.behind > 0 { text += AttributedString(" ") }
        if tracking.behind > 0 { text += AttributedString("\(tracking.behind)↓") }

        return Text(text)
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(.tertiary)
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
