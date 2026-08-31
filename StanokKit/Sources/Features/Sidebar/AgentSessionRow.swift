import SwiftUI

struct AgentSessionRow: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 11))
                .frame(width: 16)
                .foregroundStyle(.secondary)

            Text(session.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.leading, 8 + indent)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            isHovering ? AnyShapeStyle(.white.opacity(0.08)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 8, style: .continuous)
        )
        .contentShape(.rect(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
    }

    let session: AgentSession

    let indent: CGFloat

    @State
    private var isHovering = false

}
