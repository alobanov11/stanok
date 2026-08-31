import Foundation
import Testing

@testable import StanokKit

struct SplitLayoutTests {

    @Test
    func splittingToTheRightPutsTheNewPaneSecondOnTheHorizontalAxis() {
        let existing = UUID()
        let added = UUID()

        let layout = SplitLayout.leaf(existing).inserting(added, .trailing, near: existing)

        #expect(layout == .split(.horizontal, .leaf(existing), .leaf(added)))
    }

    @Test
    func splittingUpwardsPutsTheNewPaneFirstOnTheVerticalAxis() {
        let existing = UUID()
        let added = UUID()

        let layout = SplitLayout.leaf(existing).inserting(added, .top, near: existing)

        #expect(layout == .split(.vertical, .leaf(added), .leaf(existing)))
    }

    @Test
    func splittingTouchesOnlyTheTargetedLeaf() {
        let left = UUID()
        let right = UUID()
        let added = UUID()
        let layout = SplitLayout.split(.horizontal, .leaf(left), .leaf(right))

        let split = layout.inserting(added, .bottom, near: right)

        #expect(
            split == .split(
                .horizontal,
                .leaf(left),
                .split(.vertical, .leaf(right), .leaf(added))
            )
        )
    }

    @Test
    func splittingNearAnUnknownPaneChangesNothing() {
        let existing = UUID()
        let layout = SplitLayout.leaf(existing)

        #expect(layout.inserting(UUID(), .trailing, near: UUID()) == layout)
    }

    @Test
    func removingAPaneCollapsesItsSplitIntoTheSurvivor() {
        let left = UUID()
        let right = UUID()
        let layout = SplitLayout.split(.horizontal, .leaf(left), .leaf(right))

        #expect(layout.removing(right) == .leaf(left))
    }

    @Test
    func removingTheLastPaneLeavesNoLayout() {
        let only = UUID()

        #expect(SplitLayout.leaf(only).removing(only) == nil)
    }

    @Test
    func leafOrderFollowsTheLayoutFromLeadingToTrailing() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let layout = SplitLayout.split(
            .horizontal,
            .leaf(first),
            .split(.vertical, .leaf(second), .leaf(third))
        )

        #expect(layout.leafIDs == [first, second, third])
        #expect(layout.contains(second))
        #expect(!layout.contains(UUID()))
    }

    @Test
    func aLayoutSurvivesEncodingAndDecoding() throws {
        let layout = SplitLayout.split(
            .vertical,
            .leaf(UUID()),
            .split(.horizontal, .leaf(UUID()), .leaf(UUID()))
        )

        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(SplitLayout.self, from: data)

        #expect(decoded == layout)
    }
}
