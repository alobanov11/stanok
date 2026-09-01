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
            WorkspaceView { request in
                TerminalView(
                    runtime: runtime,
                    workingDirectory: request.session.url,
                    processLabel: request.session.id.uuidString,
                    isVisible: request.isVisible,
                    isFocused: request.isFocused,
                    insertRequest: request.insertRequest,
                    onCommandFinished: request.onCommandFinished,
                    onOpenURL: request.onOpenURL,
                    onTitleChanged: request.onTitleChanged,
                    onCloseRequested: request.onCloseRequested,
                    onPwdChanged: request.onPwdChanged,
                    onInput: request.onInput,
                    onInsertHandled: request.onInsertHandled,
                    closeRequest: request.closeRequest,
                    onCloseHandled: request.onCloseHandled,
                    onFocused: request.onFocused
                )
                .id(request.session.id)
            }
            .environment(\.agentSessionRegistry, agents)
            .fontDesign(.rounded)
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
