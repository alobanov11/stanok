import SwiftUI

@MainActor
struct InspectorController {

    var mode: FilePanelMode? {
        WorkspacePaths.filePanelMode(from: rawMode.wrappedValue)
    }

    var selectedFile: Binding<URL?> {
        Binding(
            get: {
                guard let session = session() else { return nil }

                return state.selectedFile(in: session.url)
                    ?? WorkspacePaths.resolvedSelectedFile(from: session)
            },
            set: { newValue in
                guard let newValue else {
                    if let session = session() {
                        state.select(nil, in: session.url)
                        persist(session.id, nil)
                    }
                    return
                }
                reveal(newValue)
            }
        )
    }

    let state: InspectorState
    let navigator: PreviewNavigator
    let session: () -> TerminalSession?
    let rawMode: Binding<String>
    let persist: (TerminalSession.ID, String?) -> Void

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

        state.select(url, in: session.url)
        persist(session.id, WorkspacePaths.relativePath(for: url, in: session.url))

        if mode != .changes {
            showAllFiles()
        }
    }

    func select(_ requested: FilePanelMode) {
        let transition = FilePanelModeTransition.resolve(current: mode, requested: requested)
        let animation: Animation? = transition.animates
            ? .smooth(duration: WorkspaceLayout.toggleDuration)
            : nil

        withAnimation(animation) {
            rawMode.wrappedValue = WorkspacePaths.rawValue(for: transition.nextMode) ?? ""
        }
    }

    func showAllFiles() {
        guard mode != .all else { return }

        let animation: Animation? = mode == nil
            ? .smooth(duration: WorkspaceLayout.toggleDuration)
            : nil

        withAnimation(animation) { rawMode.wrappedValue = "all" }
    }

    func openTree(gitDirectory: String?, onGitChange: @escaping () -> Void) {
        guard let session = session() else { return }

        state.fileTree(for: session.url).open(
            session.url,
            gitDirectory: gitDirectory,
            onGitChange: onGitChange
        )
    }
}
