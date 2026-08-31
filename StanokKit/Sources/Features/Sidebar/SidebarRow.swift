import SwiftUI

struct SidebarRow: View {

    private var iconStyle: AnyShapeStyle {
        if isMuted { return AnyShapeStyle(.tertiary) }
        return isLive ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary)
    }

    @State
    private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(iconStyle)

            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            if let usageText {
                Text(usageText)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            RowAction(icon: "xmark", hint: "Закрыть терминал", isVisible: isHovering, action: close)
        }
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isMuted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
        .padding(.leading, 8 + indent)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(
            isSelected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 10, style: .continuous)
        )
        .contentShape(.rect(cornerRadius: 10))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
    }

    let icon: String

    let title: String

    let isSelected: Bool

    let isMuted: Bool

    let isLive: Bool

    let usageText: String?

    let indent: CGFloat

    let close: () -> Void

    init(
        icon: String,
        title: String,
        isSelected: Bool,
        isMuted: Bool,
        isLive: Bool,
        usageText: String?,
        indent: CGFloat,
        close: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.isMuted = isMuted
        self.isLive = isLive
        self.usageText = usageText
        self.indent = indent
        self.close = close
    }

}
