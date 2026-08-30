import SwiftUI

struct SidebarToolbar: View {

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            button("folder.badge.plus", action: addRepository)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    let addRepository: () -> Void

    private func button(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 26, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
