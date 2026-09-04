import SwiftUI

struct SectionHeader: View {

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Typography.heading)
                .tracking(Typography.headingTracking)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Убрать из инспектора")
            }

            if let action {
                Button(action: action) {
                    Image(systemName: "rectangle.grid.1x2")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Смотреть все изменения")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    let title: String

    var action: (() -> Void)?
    var onRemove: (() -> Void)?
}
