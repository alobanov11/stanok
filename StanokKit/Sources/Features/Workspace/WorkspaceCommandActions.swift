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
        session: TerminalSession?,
        store: SessionStore,
        selection: Binding<TerminalSession.ID?>,
        closeSession: @escaping (TerminalSession) -> Void
    ) -> WorkspaceCommandActions {
        let newTerminalTab: () -> Void = {
            let url = session?.url ?? FileManager.default.homeDirectoryForCurrentUser
            selection.wrappedValue = store.addSession(url: url).id
        }

        var closeTerminalTab: (() -> Void)?
        if let session, selection.wrappedValue == session.id {
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
