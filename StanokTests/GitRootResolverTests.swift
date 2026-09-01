import Foundation
import Testing

@testable import StanokKit

struct GitRootResolverTests {

    @Test
    func aDirectoryUnderAKnownRootInheritsIt() {
        let root = "/Users/tom/Projects/app"

        #expect(GitRootResolver.inherited(for: root + "/Sources", from: [root]) == root)
        #expect(GitRootResolver.inherited(for: "/Users/tom/Other", from: [root]) == nil)
    }

    @Test
    func theLongestKnownRootWins() {
        let outer = "/Users/tom/Projects/app"
        let inner = outer + "/ThirdParty/lib"

        #expect(
            GitRootResolver.inherited(for: inner + "/Sources", from: [outer, inner]) == inner
        )
    }
}
