import Foundation
import Testing

@testable import StanokKit

struct CodeFoldingTests {

    private static func lines(_ source: [String]) -> [[CodeToken]] {
        source.map { [CodeToken(text: $0, kind: .plain)] }
    }

    @Test
    func aBracedBlockFoldsFromItsBraceToTheLineBeforeItsClose() {
        let folds = CodeFolding.folds(for: Self.lines([
            "func run() {",
            "    let a = 1",
            "    let b = 2",
            "}"
        ]))

        #expect(folds == [CodeFold(header: 0, end: 2, depth: 0)])
    }

    @Test
    func bracesInsideStringsAndCommentsDoNotOpenBlocks() {
        let folds = CodeFolding.folds(for: [
            [CodeToken(text: "let a = ", kind: .plain), CodeToken(text: "\"{\"", kind: .string)],
            [CodeToken(text: "// }", kind: .comment)],
            [CodeToken(text: "let b = 2", kind: .plain)]
        ])

        #expect(folds.isEmpty)
    }

    @Test
    func aFileWithoutBracesFallsBackToIndentation() {
        let folds = CodeFolding.folds(for: Self.lines([
            "def run():",
            "    a = 1",
            "    b = 2"
        ]))

        #expect(folds == [CodeFold(header: 0, end: 2, depth: 0)])
    }

    @Test
    func anIndentedBlockFoldsFromItsHeaderToItsLastLine() {
        let folds = CodeFolding.folds(for: Self.lines([
            "func run():",
            "    let a = 1",
            "    let b = 2"
        ]))

        #expect(folds == [CodeFold(header: 0, end: 2, depth: 0)])
    }

    @Test
    func nestedBlocksKeepTheirOwnDepth() {
        let folds = CodeFolding.folds(for: Self.lines([
            "struct A {",
            "    func run() {",
            "        let a = 1",
            "    }",
            "}"
        ]))

        #expect(folds.contains(CodeFold(header: 0, end: 3, depth: 0)))
        #expect(folds.contains(CodeFold(header: 1, end: 2, depth: 1)))
    }

    @Test
    func blankLinesInsideABlockDoNotEndIt() {
        let folds = CodeFolding.folds(for: Self.lines([
            "func run() {",
            "    let a = 1",
            "",
            "    let b = 2",
            "}"
        ]))

        #expect(folds == [CodeFold(header: 0, end: 3, depth: 0)])
    }

    @Test
    func aFlatFileHasNothingToFold() {
        #expect(CodeFolding.folds(for: Self.lines(["let a = 1", "let b = 2"])).isEmpty)
    }

    @Test
    func aFoldedHeaderHidesItsBodyButKeepsTheRest() {
        let map = CodeFoldMap(folds: [CodeFold(header: 0, end: 2, depth: 0)])

        #expect(map.visibleLines(count: 4, folded: [0]) == [0, 3])
        #expect(map.visibleLines(count: 4, folded: []) == [0, 1, 2, 3])
    }

    @Test
    func theInnermostBlockOwnsALine() {
        let map = CodeFoldMap(folds: [
            CodeFold(header: 0, end: 3, depth: 0),
            CodeFold(header: 1, end: 2, depth: 1)
        ])

        #expect(map.owner(of: 2)?.header == 1)
        #expect(map.owner(of: 3)?.header == 0)
        #expect(map.owner(of: 0) == nil)
        #expect(map.fold(startingAt: 1)?.end == 2)
    }
}
