import CoreGraphics
import Foundation
import Testing

@testable import StanokKit

struct SplitFramesTests {

    @Test
    func aSinglePaneFillsTheWholeArea() {
        let only = UUID()

        let rects = SplitFrames.rects(
            for: .leaf(only),
            in: CGSize(width: 400, height: 300),
            gap: 12
        )

        #expect(rects[only] == CGRect(x: 0, y: 0, width: 400, height: 300))
    }

    @Test
    func aHorizontalSplitHalvesTheWidthAndLeavesTheGapBetween() {
        let left = UUID()
        let right = UUID()

        let rects = SplitFrames.rects(
            for: .split(.horizontal, [.leaf(left), .leaf(right)]),
            in: CGSize(width: 412, height: 300),
            gap: 12
        )

        #expect(rects[left] == CGRect(x: 0, y: 0, width: 200, height: 300))
        #expect(rects[right] == CGRect(x: 212, y: 0, width: 200, height: 300))
    }

    @Test
    func aVerticalSplitHalvesTheHeightAndLeavesTheGapBetween() {
        let top = UUID()
        let bottom = UUID()

        let rects = SplitFrames.rects(
            for: .split(.vertical, [.leaf(top), .leaf(bottom)]),
            in: CGSize(width: 400, height: 312),
            gap: 12
        )

        #expect(rects[top] == CGRect(x: 0, y: 0, width: 400, height: 150))
        #expect(rects[bottom] == CGRect(x: 0, y: 162, width: 400, height: 150))
    }

    @Test
    func nestedSplitsDivideOnlyTheirOwnHalf() {
        let left = UUID()
        let topRight = UUID()
        let bottomRight = UUID()

        let rects = SplitFrames.rects(
            for: .split(
                .horizontal,
                [.leaf(left), .split(.vertical, [.leaf(topRight), .leaf(bottomRight)])]
            ),
            in: CGSize(width: 412, height: 312),
            gap: 12
        )

        #expect(rects[left] == CGRect(x: 0, y: 0, width: 200, height: 312))
        #expect(rects[topRight] == CGRect(x: 212, y: 0, width: 200, height: 150))
        #expect(rects[bottomRight] == CGRect(x: 212, y: 162, width: 200, height: 150))
    }

    @Test
    func anAreaSmallerThanTheGapNeverProducesNegativeSizes() {
        let left = UUID()
        let right = UUID()

        let rects = SplitFrames.rects(
            for: .split(.horizontal, [.leaf(left), .leaf(right)]),
            in: CGSize(width: 8, height: 100),
            gap: 12
        )

        #expect(rects[left]?.width == 0)
        #expect(rects[right]?.width == 0)
    }

    @Test
    func threePanesInARowGetEqualWidths() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let rects = SplitFrames.rects(
            for: .split(.horizontal, [.leaf(first), .leaf(second), .leaf(third)]),
            in: CGSize(width: 324, height: 200),
            gap: 12
        )

        #expect(rects[first] == CGRect(x: 0, y: 0, width: 100, height: 200))
        #expect(rects[second] == CGRect(x: 112, y: 0, width: 100, height: 200))
        #expect(rects[third] == CGRect(x: 224, y: 0, width: 100, height: 200))
    }

    @Test
    func threeStackedPanesGetEqualHeights() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let rects = SplitFrames.rects(
            for: .split(.vertical, [.leaf(first), .leaf(second), .leaf(third)]),
            in: CGSize(width: 200, height: 324),
            gap: 12
        )

        #expect(rects[first] == CGRect(x: 0, y: 0, width: 200, height: 100))
        #expect(rects[second] == CGRect(x: 0, y: 112, width: 200, height: 100))
        #expect(rects[third] == CGRect(x: 0, y: 224, width: 200, height: 100))
    }

    @Test
    func leftoverPointsAreSpreadSoPanesNeverDifferByMoreThanOne() {
        let ids = [UUID(), UUID(), UUID()]

        let rects = SplitFrames.rects(
            for: .split(.horizontal, ids.map { .leaf($0) }),
            in: CGSize(width: 326, height: 200),
            gap: 12
        )

        let widths = ids.compactMap { rects[$0]?.width }
        #expect(widths == [101, 101, 100])
        #expect(rects[ids[2]]?.maxX == 326)
    }
}
