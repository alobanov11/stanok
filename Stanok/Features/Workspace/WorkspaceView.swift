import SwiftUI

struct WorkspaceView: View {

    private enum Layout {

        static let inset: CGFloat = 8

        static let cardRadius: CGFloat = 12

        static let sidebarTopInset: CGFloat = 30

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
        HStack(spacing: 0) {
            sidebar
                .frame(width: Layout.sidebarIdeal)
                .padding(.top, Layout.sidebarTopInset)

            main
                .padding(.trailing, Layout.inset)
                .padding(.vertical, Layout.inset)
        }
        .ignoresSafeArea()
        .background(WindowBackground().ignoresSafeArea())
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
                .listRowBackground(Color.clear)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(.clear)
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
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
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
