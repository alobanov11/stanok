import Foundation
import Testing

import StanokKit

struct TabResourceDisplayTests {

    @Test
    func noUsageProducesNoText() {
        #expect(TabResourceDisplay.text(for: nil) == nil)
    }

    @Test
    func aFirstMeasurementWithNoCPUPercentIsHiddenEvenWithHighMemory() {
        let usage = ProcessTreeUsage(cpuPercent: nil, memoryBytes: 4 * 1_073_741_824)

        #expect(TabResourceDisplay.text(for: usage) == nil)
    }

    @Test
    func cpuBelowTheThresholdIsHidden() {
        let usage = ProcessTreeUsage(cpuPercent: 2.9, memoryBytes: 1_048_576)

        #expect(TabResourceDisplay.text(for: usage) == nil)
    }

    @Test
    func cpuAtTheThresholdIsShown() {
        let usage = ProcessTreeUsage(
            cpuPercent: TabResourceDisplay.cpuThresholdPercent,
            memoryBytes: 1_048_576
        )

        #expect(TabResourceDisplay.text(for: usage) != nil)
    }

    @Test
    func percentIsRoundedToTheNearestInteger() {
        let usage = ProcessTreeUsage(cpuPercent: 7.6, memoryBytes: 1_048_576)

        #expect(TabResourceDisplay.text(for: usage) == "8% · 1 МБ")
    }

    @Test
    func memoryUnderAGigabyteIsShownInWholeMegabytes() {
        let usage = ProcessTreeUsage(cpuPercent: 5, memoryBytes: 512 * 1_048_576)

        #expect(TabResourceDisplay.text(for: usage) == "5% · 512 МБ")
    }

    @Test
    func memoryAtOrAboveAGigabyteIsShownInGigabytesWithOneDecimal() {
        let usage = ProcessTreeUsage(cpuPercent: 5, memoryBytes: UInt64(1.5 * 1_073_741_824))

        #expect(TabResourceDisplay.text(for: usage) == "5% · 1.5 ГБ")
    }
}
