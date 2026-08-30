import SwiftUI

struct SidebarToggle: View {

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: WorkspaceLayout.toggleWidth, height: WorkspaceLayout.toggleHeight)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    let action: () -> Void

}
