import AppKit
import SwiftUI

struct RepositoryTree: View {

    let store: RepositoryStore

    @Binding
    var selection: TerminalSession.ID?

    let live: Set<TerminalSession.ID>

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 2) {
                    if !store.pinned.isEmpty {
                        SectionHeader(title: "Закреплённые")

                        ForEach(store.pinned) { item in
                            PinnedRow(pinned: item, isSelected: item.id == selection)
                                .onTapGesture { selection = item.id }
                                .contextMenu {
                                    Button("Открепить") { store.togglePin(item.id) }
                                }
                        }
                    }

                    SectionHeader(title: "Проекты")

                    ForEach(store.repositories) { repository in
                        repositoryRow(repository)

                        if repository.isExpanded {
                            ForEach(repository.sessions) { session in
                                sessionRow(session, in: repository)
                                    .transition(
                                        .opacity.combined(with: .move(edge: .top))
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .overlay(alignment: .top) {
                if store.repositories.isEmpty {
                    Text("Добавь проект")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 60)
                }
            }

            SidebarToolbar(
                canAddSession: selectedRepository != nil,
                addRepository: pickRepository,
                addSession: { addSession(to: selectedRepository) }
            )
        }
    }

    private var selectedRepository: Repository? {
        selection.flatMap { store.repository(hosting: $0) } ?? store.repositories.first
    }

    private func repositoryRow(_ repository: Repository) -> some View {
        HStack(spacing: 8) {
            Image(systemName: repository.isReachable ? "folder" : "exclamationmark.triangle")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(repository
                    .isReachable ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange)
                )

            Text(repository.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(repository
                    .isReachable ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
                )

            Spacer(minLength: 4)

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
        .onTapGesture {
            withAnimation(.smooth(duration: 0.22)) {
                store.toggleExpansion(repository.id)
            }
        }
        .help(repository.isReachable ? repository.url
            .path(percentEncoded: false) : "Папка недоступна"
        )
        .contextMenu {
            Button("Открыть в Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([repository.url])
            }
            Button("Новый терминал") {
                withAnimation(.smooth(duration: 0.22)) { addSession(to: repository) }
            }
            Button("Убрать", role: .destructive) { store.remove(repository) }
        }
    }

    private func sessionRow(_ session: TerminalSession, in repository: Repository) -> some View {
        SidebarRow(
            icon: "apple.terminal",
            title: session.name,
            isSelected: session.id == selection,
            isMuted: !repository.isReachable,
            isLive: live.contains(session.id),
            indent: 20
        )
        .onTapGesture {
            selection = session.id
            store.touch(repository.id)
        }
        .contextMenu {
            Button(session.isPinned ? "Открепить" : "Закрепить") { store.togglePin(session.id) }
            Button("Закрыть терминал", role: .destructive) {
                if selection == session.id { selection = nil }
                store.removeSession(session.id)
            }
        }
    }

    private func addSession(to repository: Repository?) {
        guard let repository else { return }

        selection = store.addSession(to: repository.id)?.id ?? selection
    }

    private func pickRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        selection = store.add(url)?.id ?? selection
    }
}
