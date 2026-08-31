import Foundation
import Testing

@testable import StanokKit

struct IgnoredPathsTests {

    private var home: URL { URL(filePath: NSHomeDirectory()) }

    @Test
    func buildArtefactsAreIgnoredWhereverTheySit() {
        #expect(IgnoredPaths.contains(URL(filePath: "/a/b/node_modules/c")))
        #expect(IgnoredPaths.contains(URL(filePath: "/a/.build/x")))
    }

    @Test
    func heavyHomeDirectoriesAreIgnored() {
        #expect(IgnoredPaths.contains(home.appending(path: "Library/Caches/x")))
        #expect(IgnoredPaths.contains(home.appending(path: ".Trash/x")))
    }

    @Test
    func theSameNamesElsewhereStayVisible() {
        #expect(!IgnoredPaths.contains(URL(filePath: "/Users/tom/Projects/app/Library/Sources")))
        #expect(!IgnoredPaths.contains(URL(filePath: "/opt/Library")))
    }

    @Test
    func ordinaryHomeContentStaysVisible() {
        #expect(!IgnoredPaths.contains(home.appending(path: "Projects/app")))
        #expect(!IgnoredPaths.contains(home))
    }

    @Test
    func exclusionsStayWithinTheFSEventsLimitOfEight() {
        #expect(IgnoredPaths.homeExclusions.count <= 8)
    }
}
