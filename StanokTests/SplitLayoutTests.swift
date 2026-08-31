import Foundation
import Testing

@testable import StanokKit

struct SplitLayoutTests {

    @Test
    func splittingToTheRightPutsTheNewPaneSecondOnTheHorizontalAxis() {
        let existing = UUID()
        let added = UUID()

        let layout = SplitLayout.leaf(existing).inserting(added, .trailing, near: existing)

        #expect(layout == .split(.horizontal, [.leaf(existing), .leaf(added)]))
    }

    @Test
    func splittingUpwardsPutsTheNewPaneFirstOnTheVerticalAxis() {
        let existing = UUID()
        let added = UUID()

        let layout = SplitLayout.leaf(existing).inserting(added, .top, near: existing)

        #expect(layout == .split(.vertical, [.leaf(added), .leaf(existing)]))
    }

    @Test
    func splittingTouchesOnlyTheTargetedLeaf() {
        let left = UUID()
        let right = UUID()
        let added = UUID()
        let layout = SplitLayout.split(.horizontal, [.leaf(left), .leaf(right)])

        let split = layout.inserting(added, .bottom, near: right)

        #expect(
            split == .split(
                .horizontal,
                [.leaf(left), .split(.vertical, [.leaf(right), .leaf(added)])]
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
        let layout = SplitLayout.split(.horizontal, [.leaf(left), .leaf(right)])

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
            [.leaf(first), .split(.vertical, [.leaf(second), .leaf(third)])]
        )

        #expect(layout.leafIDs == [first, second, third])
        #expect(layout.contains(second))
        #expect(!layout.contains(UUID()))
    }

    @Test
    func aLayoutSurvivesEncodingAndDecoding() throws {
        let layout = SplitLayout.split(
            .vertical,
            [.leaf(UUID()), .split(.horizontal, [.leaf(UUID()), .leaf(UUID())])]
        )

        let data = try JSONEncoder().encode(layout)
        let decoded = try JSONDecoder().decode(SplitLayout.self, from: data)

        #expect(decoded == layout)
    }

    @Test
    func athirdPaneOnTheSameAxisJoinsTheSameRowInsteadOfNesting() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let layout = SplitLayout.leaf(first)
            .inserting(second, .trailing, near: first)
            .inserting(third, .trailing, near: second)

        #expect(layout == .split(.horizontal, [.leaf(first), .leaf(second), .leaf(third)]))
    }

    @Test
    func aPaneAddedBeforeAnotherOneLandsInFrontOfItInTheSameRow() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let layout = SplitLayout.split(.horizontal, [.leaf(first), .leaf(second)])
            .inserting(third, .leading, near: second)

        #expect(layout == .split(.horizontal, [.leaf(first), .leaf(third), .leaf(second)]))
    }

    @Test
    func removingOneOfThreePanesLeavesTheOtherTwoInTheirRow() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let layout = SplitLayout.split(.horizontal, [.leaf(first), .leaf(second), .leaf(third)])

        #expect(layout.removing(second) == .split(.horizontal, [.leaf(first), .leaf(third)]))
    }

    @Test
    func aLayoutWrittenByTheOlderBinaryFormatStillDecodes() throws {
        let first = UUID()
        let second = UUID()
        let legacy = """
        {"split":{"_0":"horizontal","_1":{"leaf":{"_0":"\(first)"}},        "_2":{"leaf":{"_0":"\(
            second
        )"}}}}
        """

        let decoded = try JSONDecoder().decode(SplitLayout.self, from: Data(legacy.utf8))

        #expect(decoded == .split(.horizontal, [.leaf(first), .leaf(second)]))
    }
}
