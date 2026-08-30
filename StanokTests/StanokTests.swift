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

        #expect(runtime.config.float("font-size") == 20)
        #expect(runtime.config.diagnostics.isEmpty)

        runtime.tick()
    }
}
