import SwiftUI

struct PreviewBackIndicator: View {

    var body: some View {
        Button(action: action) {
            Label(name, systemImage: "chevron.backward")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(-1)
        }
        .buttonStyle(.plain)
        .help("Назад")
    }

    let name: String

    let action: () -> Void

}
