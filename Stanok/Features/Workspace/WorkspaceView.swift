import SwiftUI

struct WorkspaceView: View {

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    var body: some View {
        Group {
            if let runtime {
                TerminalView(runtime: runtime)
            } else if let failure {
                Text(failure)
                    .font(.system(.callout, design: .monospaced))
                    .padding(24)
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .task {
            do {
                runtime = try GhosttyRuntime()
            } catch {
                failure = "\(error)"
            }
        }
    }
}

#Preview {
    WorkspaceView()
}
