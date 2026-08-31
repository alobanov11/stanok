import Foundation
import Testing

@testable import StanokKit

struct CwdGenerationTrackerTests {

    @Test
    func aFreshSessionHasNoCurrentGeneration() {
        let tracker = CwdGenerationTracker()

        #expect(!tracker.isCurrent(1, for: UUID()))
    }

    @Test
    func theGenerationJustAdvancedToIsCurrent() {
        var tracker = CwdGenerationTracker()
        let id = UUID()

        let generation = tracker.advance(for: id)

        #expect(tracker.isCurrent(generation, for: id))
    }

    @Test
    func advancingAgainRejectsTheEarlierGenerationAsStale() {
        var tracker = CwdGenerationTracker()
        let id = UUID()

        let stale = tracker.advance(for: id)
        let current = tracker.advance(for: id)

        #expect(stale != current)
        #expect(!tracker.isCurrent(stale, for: id))
        #expect(tracker.isCurrent(current, for: id))
    }

    @Test
    func returningToAPreviousDirectoryStillProducesAFreshGeneration() {
        var tracker = CwdGenerationTracker()
        let id = UUID()

        let atA = tracker.advance(for: id)
        let atB = tracker.advance(for: id)
        let backAtA = tracker.advance(for: id)

        #expect(!tracker.isCurrent(atA, for: id))
        #expect(!tracker.isCurrent(atB, for: id))
        #expect(tracker.isCurrent(backAtA, for: id))
    }

    @Test
    func sessionsTrackIndependentGenerations() {
        var tracker = CwdGenerationTracker()
        let first = UUID()
        let second = UUID()

        let firstGeneration = tracker.advance(for: first)
        let secondGeneration = tracker.advance(for: second)

        #expect(tracker.isCurrent(firstGeneration, for: first))
        #expect(tracker.isCurrent(secondGeneration, for: second))
    }
}
