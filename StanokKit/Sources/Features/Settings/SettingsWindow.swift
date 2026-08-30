import SwiftUI

public struct SettingsWindow: View {

    @State
    private var selection: SettingsSection? = .appearance

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
            .navigationSplitViewColumnWidth(220)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 750, minHeight: 500)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .appearance:
            AppearanceSettings()
                .navigationTitle(SettingsSection.appearance.title)

        case nil:
            EmptyView()
        }
    }

    public init() {}

}
