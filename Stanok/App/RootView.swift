import StanokKit
import StanokTerminal
import SwiftUI

struct RootView: View {

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    @State
    private var agents = AgentSessionRegistry()

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ConfigFile.changed)) { _ in
                runtime?.reloadConfig()
            }
            .task {
                DefaultConfig.seed()
                AgentProviders.registerAll(into: agents)
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
            WorkspaceView { repository, session, active, insert, finished, openURL, title, close in
                TerminalView(
                    runtime: runtime,
                    workingDirectory: repository.url,
                    isActive: active,
                    insertRequest: insert,
                    onCommandFinished: finished,
                    onOpenURL: openURL,
                    onTitleChanged: title,
                    onCloseRequested: close
                )
                .id(session.id)
            }
            .environment(\.agentSessionRegistry, agents)
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
