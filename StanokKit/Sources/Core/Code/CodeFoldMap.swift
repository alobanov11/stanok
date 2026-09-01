import Foundation

struct CodeFoldMap: Sendable {

    static let empty = CodeFoldMap(folds: [])

    var isEmpty: Bool {
        byHeader.isEmpty
    }

    private let byHeader: [Int: CodeFold]
    private let byLine: [Int: CodeFold]

    init(folds: [CodeFold]) {
        let usable = folds.filter { $0.end > $0.header }

        self.byHeader = Dictionary(
            usable.map { ($0.header, $0) },
            uniquingKeysWith: { first, next in next.end > first.end ? next : first }
        )

        var owners: [Int: CodeFold] = [:]
        for fold in usable.sorted(by: { $0.depth < $1.depth }) {
            for line in (fold.header + 1)...fold.end {
                owners[line] = fold
            }
        }
        self.byLine = owners
    }

    func fold(startingAt line: Int) -> CodeFold? {
        byHeader[line]
    }

    func owner(of line: Int) -> CodeFold? {
        byLine[line]
    }

    func visibleLines(count: Int, folded: Set<Int>) -> [Int] {
        var visible: [Int] = []
        var index = 0

        while index < count {
            visible.append(index)

            if folded.contains(index), let fold = byHeader[index] {
                index = fold.end + 1
            } else {
                index += 1
            }
        }

        return visible
    }
}
