import SwiftUI

@MainActor
public struct WorkspaceCommandActions {

    public let toggleSidebar: () -> Void

    public let toggleAllFiles: () -> Void

    public let toggleChangedFiles: () -> Void

    public let newTerminalTab: (() -> Void)?

    public let closeTerminalTab: (() -> Void)?

    public init(
        toggleSidebar: @escaping () -> Void,
        toggleAllFiles: @escaping () -> Void,
        toggleChangedFiles: @escaping () -> Void,
        newTerminalTab: (() -> Void)?,
        closeTerminalTab: (() -> Void)?
    ) {
        self.toggleSidebar = toggleSidebar
        self.toggleAllFiles = toggleAllFiles
        self.toggleChangedFiles = toggleChangedFiles
        self.newTerminalTab = newTerminalTab
        self.closeTerminalTab = closeTerminalTab
    }

    public static func make(
        toggleSidebar: @escaping () -> Void,
        selectFilesMode: @escaping (FilePanelMode) -> Void,
        repository: Repository?,
        store: RepositoryStore,
        selection: Binding<TerminalSession.ID?>,
        closeSession: @escaping (TerminalSession) -> Void
    ) -> WorkspaceCommandActions {
        var newTerminalTab: (() -> Void)?
        if let repository {
            newTerminalTab = {
                let added = store.addSession(to: repository.id)?.id
                selection.wrappedValue = added ?? selection.wrappedValue
            }
        }

        var closeTerminalTab: (() -> Void)?
        if
            let currentSelection = selection.wrappedValue,
            let session = repository?.sessions.first(where: { $0.id == currentSelection }) {
            closeTerminalTab = { closeSession(session) }
        }

        return WorkspaceCommandActions(
            toggleSidebar: toggleSidebar,
            toggleAllFiles: { selectFilesMode(.all) },
            toggleChangedFiles: { selectFilesMode(.changes) },
            newTerminalTab: newTerminalTab,
            closeTerminalTab: closeTerminalTab
        )
    }
}
