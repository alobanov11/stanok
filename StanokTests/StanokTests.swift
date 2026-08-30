import Testing

@testable import Stanok

@MainActor
struct StanokTests {

    @Test
    func ghosttyReportsAVersion() {
        #expect(GhosttyInfo.version != "unknown")
        #expect(GhosttyInfo.buildMode == "release-fast")
    }

    @Test
    func runtimeBootsAndReadsConfig() throws {
        let runtime = try GhosttyRuntime()

        #expect(runtime.config.number("font-size") != nil)
        #expect(runtime.config.diagnostics.isEmpty)

        runtime.tick()
    }
}
