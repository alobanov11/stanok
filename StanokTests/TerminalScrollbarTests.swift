import Foundation
import Testing

@testable import StanokKit

struct TerminalScrollbarTests {

    @Test
    func aViewportLargerThanTheBufferStaysAtTheTop() {
        let scrollbar = TerminalScrollbar(total: 10, offset: 0, length: 40)

        #expect(scrollbar.position == 0)
        #expect(!scrollbar.isScrollable)
    }

    @Test
    func theOffsetMapsOntoTheTravelledPart() {
        let scrollbar = TerminalScrollbar(total: 100, offset: 40, length: 20)

        #expect(scrollbar.isScrollable)
        #expect(scrollbar.position == 0.5)
    }
}
