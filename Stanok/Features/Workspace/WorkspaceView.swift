import SwiftUI

struct WorkspaceView: View {

    private enum Layout {

        static let inset: CGFloat = 12

        static let cardRadius: CGFloat = 12

        static let sidebarMin: CGFloat = 200

        static let sidebarIdeal: CGFloat = 240

        static let sidebarMax: CGFloat = 340
    }

    @State
    private var model = WorkspaceModel()

    @State
    private var runtime: GhosttyRuntime?

    @State
    private var failure: String?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: Layout.sidebarMin,
                    ideal: Layout.sidebarIdeal,
                    max: Layout.sidebarMax
                )
        } detail: {
            main
                .padding(Layout.inset)
                .navigationTitle("stanok")
        }
        .navigationSplitViewStyle(.prominentDetail)
        .containerBackground(.thinMaterial, for: .window)
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
        List(model.runs) { run in
            CommandRow(run: run)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .overlay {
            if model.runs.isEmpty {
                ContentUnavailableView(
                    "Пока пусто",
                    systemImage: "terminal",
                    description: Text("Здесь появятся завершённые команды")
                )
            }
        }
    }

    @ViewBuilder
    private var main: some View {
        if let runtime {
            TerminalView(runtime: runtime) { model.record($0) }
                .clipShape(.rect(cornerRadius: Layout.cardRadius, style: .continuous))
        } else if let failure {
            ContentUnavailableView("Терминал не запустился", systemImage: "exclamationmark.triangle", description: Text(failure))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    WorkspaceView()
}
