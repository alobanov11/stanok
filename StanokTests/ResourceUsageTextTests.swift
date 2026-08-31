import Foundation
import Testing

import StanokKit

struct ResourceUsageTextTests {

    @Test
    func missingUsageIsShownAsADash() {
        #expect(ResourceUsageText.text(for: nil) == "—")
    }

    @Test
    func aFirstMeasurementWithoutAPercentStillShowsMemory() {
        let usage = ProcessTreeUsage(cpuPercent: nil, memoryBytes: 180 * 1_048_576)

        #expect(ResourceUsageText.text(for: usage) == "180 МБ")
    }

    @Test
    func anIdleProcessIsStillShown() {
        let usage = ProcessTreeUsage(cpuPercent: 0, memoryBytes: 1_048_576)

        #expect(ResourceUsageText.text(for: usage) == "1 МБ")
    }

    @Test
    func memoryAtOrAboveAGigabyteSwitchesUnits() {
        let usage = ProcessTreeUsage(cpuPercent: 5, memoryBytes: UInt64(1.5 * 1_073_741_824))

        #expect(ResourceUsageText.text(for: usage) == "1.5 ГБ")
    }
}
