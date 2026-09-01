import SwiftUI

struct SidebarRow: View {

    private var background: AnyShapeStyle {
        if isDropTarget { return AnyShapeStyle(Color.accentColor.opacity(0.28)) }

        return isSelected ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.clear)
    }

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

            if isHovering {
                RowAction(icon: "xmark", hint: "Закрыть терминал", action: close)
            } else {
                Color.clear.frame(width: 20, height: 18)
            }
        }
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isMuted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
        .padding(.leading, 8 + indent)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(
            background,
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
    let isDropTarget: Bool
    let indent: CGFloat
    let close: () -> Void

    init(
        icon: String,
        title: String,
        isSelected: Bool,
        isMuted: Bool,
        isLive: Bool,
        indent: CGFloat,
        isDropTarget: Bool = false,
        close: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.isMuted = isMuted
        self.isLive = isLive
        self.indent = indent
        self.isDropTarget = isDropTarget
        self.close = close
    }
}
