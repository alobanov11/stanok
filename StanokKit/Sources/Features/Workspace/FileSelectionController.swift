import SwiftUI

@MainActor
struct FileSelectionController {

    let selectedFile: Binding<URL?>

    let filesMode: Binding<FilePanelMode?>

    let store: RepositoryStore

    let navigator: PreviewNavigator

    let repository: () -> Repository?

    func restoreWorkspace() {
        guard let repository = repository() else { return }

        if let resolved = WorkspacePaths.resolvedSelectedFile(from: repository) {
            selectedFile.wrappedValue = resolved
        }

        filesMode.wrappedValue = WorkspacePaths.filePanelMode(from: repository.workspace.panelMode)
    }

    func open(_ url: URL) {
        reveal(url)

        Task {
            await navigator.openFile(url)
        }
    }

    func reveal(_ url: URL) {
        guard
            let repository = repository(),
            WorkspacePaths.contains(repository.url, url)
        else { return }

        selectedFile.wrappedValue = url

        if filesMode.wrappedValue != .changes {
            showAllFiles()
        }

        if let relative = WorkspacePaths.relativePath(for: url, in: repository.url) {
            store.updateWorkspace(repository.id) { $0.selectedFile = relative }
        }
    }

    func showAllFiles() {
        guard filesMode.wrappedValue != .all else { return }

        if filesMode.wrappedValue == nil {
            withAnimation(.smooth(duration: WorkspaceLayout.toggleDuration)) {
                filesMode.wrappedValue = .all
            }
        } else {
            filesMode.wrappedValue = .all
        }

        persistPanelMode()
    }

    func persistPanelMode() {
        guard let repository = repository() else { return }

        store.updateWorkspace(repository.id) {
            $0.panelMode = WorkspacePaths.rawValue(for: filesMode.wrappedValue)
        }
    }
}
