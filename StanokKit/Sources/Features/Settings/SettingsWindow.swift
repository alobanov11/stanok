import SwiftUI

public struct SettingsWindow: View {

    @State
    private var selection: SettingsSection? = .terminal

    public var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selection) {
                ForEach(SettingsSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 620, idealWidth: 660, minHeight: 400, idealHeight: 440)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .terminal:
            TerminalSettings()
                .navigationTitle(SettingsSection.terminal.title)

        case .preview:
            PreviewSettings()
                .navigationTitle(SettingsSection.preview.title)

        case nil:
            EmptyView()
        }
    }

    public init() {}

}
