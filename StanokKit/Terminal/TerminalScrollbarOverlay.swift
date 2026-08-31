import StanokKit
import SwiftUI

struct TerminalScrollbarOverlay: View {

    private enum Metric {

        static let width: CGFloat = 4
        static let hitWidth: CGFloat = 16
        static let inset: CGFloat = 3
        static let minimumThumb: CGFloat = 28
        static let idleDelay = Duration.seconds(1.2)
    }

    private var isInteractive: Bool {
        scrollbar?.isScrollable == true && (isShown || isHovering || grab != nil)
    }

    private var isVisible: Bool {
        isShown || isHovering || grab != nil
    }

    @State
    private var isShown = false

    @State
    private var isHovering = false

    @State
    private var grab: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            track(in: proxy.size.height)
                .frame(width: Metric.hitWidth)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, Metric.inset)
        .frame(width: Metric.hitWidth + Metric.inset)
        .allowsHitTesting(isInteractive)
        .task(id: scrollbar) { await settle() }
    }

    let scrollbar: TerminalScrollbar?
    let controller: TerminalScrollController

    @ViewBuilder
    private func track(in height: CGFloat) -> some View {
        if let scrollbar, scrollbar.isScrollable {
            let thumb = min(max(height * scrollbar.thumbFraction, Metric.minimumThumb), height)
            let travel = max(height - thumb, 0)

            Color.clear
                .contentShape(.rect)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(.white.opacity(isHovering || grab != nil ? 0.5 : 0.32))
                        .frame(width: Metric.width, height: thumb)
                        .offset(y: travel * scrollbar.position)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, Metric.inset)
                        .opacity(isVisible ? 1 : 0)
                }
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
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
            .onEnded { _ in grab = nil }
    }

    func grabOffset(at point: CGFloat, thumbTop: CGFloat, thumb: CGFloat) -> CGFloat {
        let inside = point >= thumbTop && point <= thumbTop + thumb

        return inside ? point - thumbTop : thumb / 2
    }

    func scrollTo(position: Double, _ scrollbar: TerminalScrollbar) {
        let span = Double(scrollbar.total - scrollbar.length)
        let target = (min(max(position, 0), 1) * span).rounded()
        let rows = Int(target) - Int(scrollbar.offset)

        controller.scroll(rows: rows)
    }

    func settle() async {
        guard scrollbar?.isScrollable == true else {
            isShown = false
            return
        }

        withAnimation(.easeOut(duration: 0.12)) { isShown = true }

        try? await Task.sleep(for: Metric.idleDelay)
        guard !Task.isCancelled, grab == nil, !isHovering else { return }

        withAnimation(.easeOut(duration: 0.35)) { isShown = false }
    }
}
