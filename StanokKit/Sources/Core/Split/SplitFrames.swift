import CoreGraphics
import Foundation

public enum SplitFrames {

    public static func rects(
        for layout: SplitLayout,
        in size: CGSize,
        gap: CGFloat
    ) -> [UUID: CGRect] {
        var rects: [UUID: CGRect] = [:]
        let area = CGRect(
            origin: .zero,
            size: CGSize(width: size.width.rounded(.down), height: size.height.rounded(.down))
        )
        fill(layout, area, gap: gap, into: &rects)
        return rects
    }

    private static func fill(
        _ layout: SplitLayout,
        _ rect: CGRect,
        gap: CGFloat,
        into rects: inout [UUID: CGRect]
    ) {
        switch layout {
        case let .leaf(id):
            rects[id] = rect

        case let .split(axis, children):
            let slots = slots(in: rect, axis: axis, gap: gap, count: children.count)

            for (child, slot) in zip(children, slots) {
                fill(child, slot, gap: gap, into: &rects)
            }
        }
    }

    private static func slots(
        in rect: CGRect,
        axis: SplitAxis,
        gap: CGFloat,
        count: Int
    ) -> [CGRect] {
        guard count > 0 else { return [] }

        let total = axis == .horizontal ? rect.width : rect.height
        let available = max(total - gap * CGFloat(count - 1), 0)
        let base = (available / CGFloat(count)).rounded(.down)
        var spare = available - base * CGFloat(count)
        var offset = axis == .horizontal ? rect.minX : rect.minY

        return (0..<count).map { _ in
            var length = base
            if spare >= 1 {
                length += 1
                spare -= 1
            }

            let slot = axis == .horizontal
                ? CGRect(x: offset, y: rect.minY, width: length, height: rect.height)
                : CGRect(x: rect.minX, y: offset, width: rect.width, height: length)
            offset += length + gap
            return slot
        }
    }
}
