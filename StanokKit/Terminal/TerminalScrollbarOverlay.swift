import StanokKit
import SwiftUI

struct TerminalScrollbarOverlay: View {

    private enum Metric {

        static let width: CGFloat = 4
        static let hitWidth: CGFloat = 16
        static let inset: CGFloat = 3
        static let minimumThumb: CGFloat = 28
    }

    private enum Appearance {

        case hidden
        case idle
        case visible
    }

    private var active: TerminalScrollbar? {
        guard let scrollbar = controller.scrollbar, scrollbar.isScrollable else { return nil }

        return scrollbar
    }

    private var appearance: Appearance {
        guard active != nil else { return .hidden }

        return controller.isShown || isHovering || grab != nil ? .visible : .idle
    }

    @State
    private var isHovering = false

    @State
    private var grab: CGFloat?

    @State
    private var target: Int?

    @State
    private var dragPosition: Double?

    var body: some View {
        GeometryReader { proxy in
            track(in: proxy.size.height)
                .frame(width: Metric.hitWidth)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, Metric.inset)
        .frame(width: Metric.hitWidth + Metric.inset)
        .allowsHitTesting(appearance != .hidden)

    }

    let controller: TerminalScrollController

    @ViewBuilder
    private func track(in height: CGFloat) -> some View {
        if let scrollbar = active {
            let thumb = min(max(height * scrollbar.thumbFraction, Metric.minimumThumb), height)
            let travel = max(height - thumb, 0)

            Color.clear
                .contentShape(.rect)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.white.opacity(isHovering || grab != nil ? 0.5 : 0.32))
                        .frame(width: Metric.width, height: thumb)
                        .offset(y: travel * (dragPosition ?? scrollbar.position))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, Metric.inset)
                        .opacity(appearance == .visible ? 1 : 0)
                }
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
                    if hovering { controller.show() }
                }
                .gesture(drag(scrollbar, thumb: thumb, travel: travel))
        }
    }
}

private extension TerminalScrollbarOverlay {

    func drag(
        _ scrollbar: TerminalScrollbar,
        thumb: CGFloat,
        travel: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let thumbTop = travel * scrollbar.position
                let offset = grab ?? grabOffset(
                    at: value.location.y,
                    thumbTop: thumbTop,
                    thumb: thumb
                )
                grab = offset

                scrollTo(position: travel > 0 ? (value.location.y - offset) / travel : 0, scrollbar)
            }
            .onEnded { _ in
                grab = nil
                target = nil
                dragPosition = nil
            }
    }

    func grabOffset(at point: CGFloat, thumbTop: CGFloat, thumb: CGFloat) -> CGFloat {
        let inside = point >= thumbTop && point <= thumbTop + thumb

        return inside ? point - thumbTop : thumb / 2
    }

    func scrollTo(position: Double, _ scrollbar: TerminalScrollbar) {
        let clamped = min(max(position, 0), 1)
        dragPosition = clamped

        let span = scrollbar.total > scrollbar.length ? scrollbar.total - scrollbar.length : 0
        let next = Int((clamped * Double(span)).rounded())
        guard next != target else { return }

        target = next
        controller.scroll(toRow: next)
    }
}
