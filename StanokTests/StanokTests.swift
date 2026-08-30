import Testing

@testable import Stanok

struct StanokTests {

    @Test
    func ghosttyReportsAVersion() {
        #expect(GhosttyInfo.version != "unknown")
        #expect(GhosttyInfo.buildMode == "release-fast")
    }
}
