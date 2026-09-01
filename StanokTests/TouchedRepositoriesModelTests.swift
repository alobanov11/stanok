import Foundation
import Testing

import StanokKit

@MainActor
struct TouchedRepositoriesModelTests {

    @Test
    func aCancelledCallerDoesNotAbandonTheRefresh() async throws {
        let source = HeldTouchesSource()
        let model = TouchedRepositoriesModel()
        model.use(source)

        let call = Task { await model.refresh() }
        await source.waitUntilStarted()
        call.cancel()
        await source.release()

        try await settle { model.checkedAt != nil }

        #expect(model.checkedAt != nil)
        #expect(await source.callCount == 1)
    }

    @Test
    func aSecondRefreshJoinsTheOneInFlight() async throws {
        let source = HeldTouchesSource()
        let model = TouchedRepositoriesModel()
        model.use(source)

        let first = Task { await model.refresh() }
        await source.waitUntilStarted()

        let second = Task { await model.refresh() }
        await source.release()

        await first.value
        await second.value

        #expect(await source.callCount == 1)
        #expect(model.isLoading == false)
    }

    private func settle(until ready: () -> Bool) async throws {
        for _ in 0..<200 {
            if ready() { return }

            try await Task.sleep(for: .milliseconds(10))
        }

        Issue.record("Обновление не завершилось")
    }
}
