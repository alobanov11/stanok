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

        case let .split(axis, first, second):
            let halves = halves(of: rect, axis: axis, gap: gap)
            fill(first, halves.0, gap: gap, into: &rects)
            fill(second, halves.1, gap: gap, into: &rects)
        }
    }

    private static func halves(
        of rect: CGRect,
        axis: SplitAxis,
        gap: CGFloat
    ) -> (CGRect, CGRect) {
        switch axis {
        case .horizontal:
            let first = max(((rect.width - gap) / 2).rounded(.down), 0)
            let second = max(rect.width - gap - first, 0)
            return (
                CGRect(x: rect.minX, y: rect.minY, width: first, height: rect.height),
                CGRect(x: rect.maxX - second, y: rect.minY, width: second, height: rect.height)
            )

        case .vertical:
            let first = max(((rect.height - gap) / 2).rounded(.down), 0)
            let second = max(rect.height - gap - first, 0)
            return (
                CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: first),
                CGRect(x: rect.minX, y: rect.maxY - second, width: rect.width, height: second)
            )
        }
    }
}
