import SwiftUI

struct CardStylePreview: View {

    private enum Layout {

        static let inset: CGFloat = 8

        static let cardRadius: CGFloat = 12

        static let sidebarWidth: CGFloat = 180

        static let rowHeight: CGFloat = 260
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(CardStyle.allCases) { style in
                sample(style)
                    .frame(height: Layout.rowHeight)
            }
        }
        .frame(width: 720)
        .background(desktop)
    }

    private var desktop: some View {
        LinearGradient(
            colors: [
                .init(red: 0.09, green: 0.13, blue: 0.28),
                .init(red: 0.05, green: 0.22, blue: 0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("tom@MacBook-Pro ~ %  ls -la")
            Text("drwxr-xr-x   12 tom  staff   384 Aug 30 18:41 .")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sample(_ style: CardStyle) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(style.rawValue)
                    .font(.system(size: 12, weight: .semibold))

                Text("exit 0")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(14)
            .frame(width: Layout.sidebarWidth, alignment: .leading)

            terminal
                .background { style.background(radius: Layout.cardRadius) }
                .padding(.trailing, Layout.inset)
                .padding(.vertical, Layout.inset)
        }
    }

}

#Preview("Стили карточки") {
    CardStylePreview()
}
