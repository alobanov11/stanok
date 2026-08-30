import SwiftUI

struct WorkspaceView: View {

    private static let inset: CGFloat = 10

    @State
    private var model = WorkspaceModel()

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 232)

            main
                .padding(.trailing, Self.inset)
                .padding(.vertical, Self.inset)
        }
        .background(VisualEffectView(material: .underWindowBackground).ignoresSafeArea())
        .frame(minWidth: 880, minHeight: 520)
        .task {
            do {
                runtime = try GhosttyRuntime()
            } catch {
                failure = "\(error)"
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("stanok")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Text("История")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(model.runs) { run in
                        CommandRow(run: run)
                    }
                }
                .padding(.horizontal, 6)
            }
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)
        }
        .padding(.top, 34)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            if model.runs.isEmpty {
                Text("команды появятся здесь")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .padding(.top, 90)
            }
        }
    }

    @ViewBuilder
    private var main: some View {
        if let runtime {
            TerminalView(runtime: runtime) { model.record($0) }
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 3)
        } else if let failure {
            Text(failure)
                .font(.system(.callout, design: .monospaced))
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background, in: .rect(cornerRadius: 10))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background, in: .rect(cornerRadius: 10))
        }
    }
}

#Preview {
    WorkspaceView()
}
