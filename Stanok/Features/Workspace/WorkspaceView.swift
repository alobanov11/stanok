import SwiftUI

struct WorkspaceView: View {

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("stanok")
                .font(.largeTitle.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            row("libghostty", "\(GhosttyInfo.version) · \(GhosttyInfo.buildMode)")

            if let runtime {
                row("runtime", "booted")
                row("font-family", runtime.config.text("font-family") ?? "—")
                row("font-size", runtime.config.number("font-size").map { "\($0)" } ?? "—")
                row("diagnostics", "\(runtime.config.diagnostics.count)")
            }

            if let failure {
                row("error", failure)
            }
        }
        .font(.system(.callout, design: .monospaced))
        .padding(24)
        .frame(minWidth: 460, minHeight: 260)
        .task {
            do {
                runtime = try GhosttyRuntime()
            } catch {
                failure = "\(error)"
            }
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(key)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
        }
    }
}

#Preview {
    WorkspaceView()
}
