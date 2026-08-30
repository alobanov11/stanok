import SwiftUI

struct PinnedRow: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pin.fill")
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(pinned.session.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Text(pinned.repository.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 10, style: .continuous)
        )
        .contentShape(.rect(cornerRadius: 10))
    }

    let pinned: PinnedSession

    let isSelected: Bool

}
