import SwiftUI

struct TerminalHeader: View {

    private var hasChanges: Bool {
        status?.hasChanges ?? false
    }

    private var badgeBackground: AnyShapeStyle {
        AnyShapeStyle(.white.opacity(0.05))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            folderBadge((session.liveDirectory ?? session.url).lastPathComponent)

            if let status, let branch = status.branch {
                branchBadge(branch)

                if status.hasChanges {
                    changesBadge(status)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, 48)
        .frame(height: WorkspaceLayout.headerHeight)
        .overlay(alignment: .trailing) {
            actionsMenu
                .padding(.trailing, 12)
        }
    }

    private var actionsMenu: some View {
        Menu {
            Menu("Добавить") {
                Button("Снизу") { split(.bottom) }

                Button("Справа") { split(.trailing) }

                Button("Слева") { split(.leading) }

                Button("Сверху") { split(.top) }
            }

            Button("Новый терминал", action: newTerminal)

            Button("Закрыть", role: .destructive, action: close)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 20)
                .contentShape(.capsule)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Действия с терминалом")
    }

    let session: TerminalSession

    let status: GitStatus?

    let leadingInset: CGFloat

    let filesMode: FilePanelMode?

    let isBusy: Bool

    let selectAll: () -> Void

    let selectChanges: () -> Void

    let selectBranches: () -> Void

    let stashChanges: () -> Void

    let discardChanges: () -> Void

    let split: (SplitDirection) -> Void

    let newTerminal: () -> Void

    let close: () -> Void

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
            .background(background(for: .all), in: .capsule)
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
                .background(background(for: .branches), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(filesMode == .branches ? "Скрыть ветки" : "Показать ветки")
    }

    private func changesBadge(_ status: GitStatus) -> some View {
        Button(action: selectChanges) {
            counters(status)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(background(for: .changes), in: .capsule)
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
        let added = attributed("+\(status.added)", .green)
        let removed = attributed("−\(status.removed)", .red)

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

    private func background(for mode: FilePanelMode) -> AnyShapeStyle {
        filesMode == mode ? AnyShapeStyle(.white.opacity(0.14)) : badgeBackground
    }

    private func attributed(_ text: String, _ color: Color) -> AttributedString {
        var value = AttributedString(text)
        value.foregroundColor = color
        return value
    }

}
