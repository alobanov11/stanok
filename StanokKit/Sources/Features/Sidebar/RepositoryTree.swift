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
            .dropDestination(for: URL.self) { items, _ in
                for url in items.reversed() where isDirectory(url) {
                    selection = store.add(url)?.id ?? selection
                }
            }

            SidebarToolbar(addRepository: pickRepository)
        }
    }

    private func repositoryRow(_ repository: Repository) -> some View {
        RepositoryRow(
            repository: repository,
            toggle: { toggleExpansion(repository) },
            addSession: { addSession(to: repository) },
            remove: { store.remove(repository) }
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
            indent: 20,
            close: { closeSession(session) }
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

    private func toggleExpansion(_ repository: Repository) {
        withAnimation(.smooth(duration: 0.22)) { store.toggleExpansion(repository.id) }
    }

    private func closeSession(_ session: TerminalSession) {
        if selection == session.id { selection = nil }

        withAnimation(.smooth(duration: 0.22)) { store.removeSession(session.id) }
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

    private func isDirectory(_ url: URL) -> Bool {
        var flag: ObjCBool = false
        let path = url.path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: path, isDirectory: &flag) && flag.boolValue
    }
}
