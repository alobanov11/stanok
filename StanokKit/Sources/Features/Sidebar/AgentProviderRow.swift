import SwiftUI

struct AgentProviderRow: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12)
        }
        .padding(.leading, 8 + indent)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .contentShape(.rect(cornerRadius: 10))
        .onTapGesture(perform: toggle)
    }

    let title: String

    let indent: CGFloat

    let isExpanded: Bool

    let toggle: () -> Void

}
