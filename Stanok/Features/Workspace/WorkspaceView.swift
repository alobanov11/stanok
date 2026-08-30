import SwiftUI

struct WorkspaceView: View {

    @State
    private var model = WorkspaceModel()

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    var body: some View {
        HSplitView {
            history
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 360)

            terminal
                .frame(minWidth: 480)
        }
        .frame(minWidth: 900, minHeight: 480)
        .task {
            do {
                runtime = try GhosttyRuntime()
            } catch {
                failure = "\(error)"
            }
        }
    }

    @ViewBuilder
    private var terminal: some View {
        if let runtime {
            TerminalView(runtime: runtime) { model.record($0) }
        } else if let failure {
            Text(failure)
                .font(.system(.callout, design: .monospaced))
                .padding(24)
        } else {
            ProgressView()
        }
    }

    private var history: some View {
        List(model.runs) { run in
            HStack(spacing: 8) {
                Circle()
                    .fill(run.succeeded ? Color.green : Color.red)
                    .frame(width: 7, height: 7)

                Text(run.exitCode.map { "exit \($0)" } ?? "no exit code")

                Spacer()

                Text(run.duration.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))
                    .foregroundStyle(.secondary)
            }
            .font(.system(.caption, design: .monospaced))
        }
        .overlay {
            if model.runs.isEmpty {
                Text("команды появятся здесь")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WorkspaceView()
}
