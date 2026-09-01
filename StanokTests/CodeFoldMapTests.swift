import Foundation
import Testing

@testable import StanokKit

struct CodeFoldMapTests {

    @Test
    func aFoldWithoutHiddenLinesIsDropped() {
        let map = CodeFoldMap(folds: [CodeFold(header: 0, end: 0, depth: 0)])

        #expect(map.isEmpty)
        #expect(map.fold(startingAt: 0) == nil)
    }

    @Test
    func twoFoldsOnOneHeaderKeepTheOuterOne() {
        let map = CodeFoldMap(folds: [
            CodeFold(header: 2, end: 4, depth: 1),
            CodeFold(header: 2, end: 9, depth: 0)
        ])

        #expect(map.fold(startingAt: 2)?.end == 9)
    }

    @Test
    func anEmptyBlockDoesNotBecomeAFold() {
        let folds = CodeFolding.folds(for: [
            [CodeToken(text: "func run() {", kind: .plain)],
            [CodeToken(text: "}", kind: .plain)]
        ])

        #expect(folds.isEmpty)
        #expect(CodeFoldMap(folds: folds).isEmpty)
    }
}
