import SwiftUI

struct FilePanel: View {

    var body: some View {
        VStack(spacing: 0) {
            header
            FileTree(url: url, selected: $selected, onOpen: onOpen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Файлы")
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: WorkspaceLayout.headerHeight)
    }

    let url: URL?

    @Binding
    var selected: URL?

    let onOpen: (URL) -> Void

}
