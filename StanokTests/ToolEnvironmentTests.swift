import Foundation
import Testing

@testable import StanokKit

struct ToolEnvironmentTests {

    @Test
    func pathIsTakenFromBetweenTheMarkers() {
        let output = "приветствие оболочки\n\u{1}/opt/homebrew/bin:/usr/bin\u{2}\n"

        #expect(ToolEnvironment.extract(output) == "/opt/homebrew/bin:/usr/bin")
    }

    @Test
    func outputWithoutMarkersYieldsNothing() {
        #expect(ToolEnvironment.extract("/usr/bin:/bin") == nil)
    }

    @Test
    func missingOutputYieldsNothing() {
        #expect(ToolEnvironment.extract(nil) == nil)
    }

    @Test
    func theResolvedEnvironmentCarriesAPath() {
        #expect(ToolEnvironment.current["PATH"]?.isEmpty == false)
    }
}
