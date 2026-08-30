import SwiftUI

struct RowAction: View {

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 18)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(hint)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
    }

    let icon: String

    let hint: String

    let isVisible: Bool

    let action: () -> Void

}
