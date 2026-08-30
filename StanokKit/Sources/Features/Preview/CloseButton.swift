import SwiftUI

struct CloseButton: View {

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(
                    width: WorkspaceLayout.toggleHeight,
                    height: WorkspaceLayout.toggleHeight
                )
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help("Закрыть")
    }

    let action: () -> Void

}
