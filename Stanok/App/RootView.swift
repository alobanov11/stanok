import StanokKit
import StanokTerminal
import SwiftUI

struct RootView: View {

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
                runtime?.reloadConfig()
            }
            .task {
                DefaultConfig.seed()
                do {
                    runtime = try GhosttyRuntime()
                } catch {
                    failure = "\(error)"
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let runtime {
            WorkspaceView { repository, session, isActive, onCommandFinished, onOpenURL, onClose in
                TerminalView(
                    runtime: runtime,
                    workingDirectory: repository.url,
                    isActive: isActive,
                    onCommandFinished: onCommandFinished,
                    onOpenURL: onOpenURL,
                    onCloseRequested: onClose
                )
                .id(session.id)
            }
        } else if let failure {
            ContentUnavailableView(
                "Терминал не запустился",
                systemImage: "exclamationmark.triangle",
                description: Text(failure)
            )
            .frame(minWidth: 880, minHeight: 520)
        } else {
            ProgressView()
                .frame(minWidth: 880, minHeight: 520)
        }
    }
}
