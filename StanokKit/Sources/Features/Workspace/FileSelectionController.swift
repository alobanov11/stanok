import SwiftUI

@MainActor
struct FileSelectionController {

    let selectedFile: Binding<URL?>

    let filesMode: Binding<FilePanelMode?>

    let store: SessionStore

    let navigator: PreviewNavigator

    let session: () -> TerminalSession?

    func restoreWorkspace() {
        guard let session = session() else { return }

        if let resolved = WorkspacePaths.resolvedSelectedFile(from: session) {
            selectedFile.wrappedValue = resolved
        }

        filesMode.wrappedValue = WorkspacePaths.filePanelMode(from: session.workspace.panelMode)
    }

    func open(_ url: URL) {
        reveal(url)

        Task {
            await navigator.openFile(url)
        }
    }

    func reveal(_ url: URL) {
        guard
            let session = session(),
            WorkspacePaths.contains(session.url, url)
        else { return }

        selectedFile.wrappedValue = url

        if filesMode.wrappedValue != .changes {
            showAllFiles()
        }

        if let relative = WorkspacePaths.relativePath(for: url, in: session.url) {
            store.updateWorkspace(session.id) { $0.selectedFile = relative }
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
        guard let session = session() else { return }

        store.updateWorkspace(session.id) {
            $0.panelMode = WorkspacePaths.rawValue(for: filesMode.wrappedValue)
        }
    }
}
