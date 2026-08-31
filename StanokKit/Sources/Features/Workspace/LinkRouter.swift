import AppKit
import SwiftUI

@MainActor
struct LinkRouter {

    let navigator: PreviewNavigator

    let openFile: (URL) -> Void

    func route(_ url: URL) {
        if url.scheme == "http" || url.scheme == "https" {
            navigator.openWeb(url)
            return
        }

        guard url.isFileURL else {
            NSWorkspace.shared.open(url)
            return
        }

        openFile(URL(fileURLWithPath: url.path))
    }

    func handleLink(_ url: URL) -> OpenURLAction.Result {
        route(url)
        return .handled
    }

    func openTerminalLink(_ raw: String, in repository: Repository) {
        let resolved = WorkspacePaths.resolvedURL(from: raw, relativeTo: repository.url)
        guard let url = resolved else { return }

        route(url)
    }
}
