import Foundation
import Testing

@testable import StanokKit

@MainActor
struct FoldedChangeTests {

    @Test
    func aChangeInsideAnOuterFoldedBlockIsProjectedOntoIt() throws {
        let folds = CodeFoldMap(folds: [
            CodeFold(header: 0, end: 20, depth: 0),
            CodeFold(header: 5, end: 10, depth: 1)
        ])

        let line = CodeDocumentBuilder.visibleLine(7, folds: folds, folded: [0])

        #expect(line == 0)
    }

    @Test
    func aChangeInsideAnOpenBlockKeepsItsLine() throws {
        let folds = CodeFoldMap(folds: [CodeFold(header: 0, end: 20, depth: 0)])

        #expect(CodeDocumentBuilder.visibleLine(7, folds: folds, folded: []) == 7)
    }
}
