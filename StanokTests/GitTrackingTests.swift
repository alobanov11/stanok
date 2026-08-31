import Foundation
import Testing

import StanokKit

struct GitTrackingTests {

    @Test
    func aheadAndBehindAreReadInOrder() {
        #expect(GitTracking.parse("0\t106") == GitTracking(ahead: 0, behind: 106))
        #expect(GitTracking.parse("3\t0") == GitTracking(ahead: 3, behind: 0))
    }

    @Test
    func spacesSeparateJustAsTabsDo() {
        #expect(GitTracking.parse("2 5\n") == GitTracking(ahead: 2, behind: 5))
    }

    @Test
    func aBranchWithNoUpstreamHasNoDivergence() {
        #expect(GitTracking.parse(nil) == .none)
        #expect(GitTracking.parse("") == .none)
        #expect(GitTracking.parse("fatal: no upstream configured") == .none)
    }

    @Test
    func divergenceIsReportedOnlyWhenSomethingDiffers() {
        #expect(GitTracking.none.hasDivergence == false)
        #expect(GitTracking(ahead: 0, behind: 1).hasDivergence)
        #expect(GitTracking(ahead: 1, behind: 0).hasDivergence)
    }
}
