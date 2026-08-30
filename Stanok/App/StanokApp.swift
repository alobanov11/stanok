import SwiftUI

@main
struct StanokApp: App {

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
