import Foundation

enum MarkdownSection: Sendable {

    case block(MarkdownBlock)
    case quote([MarkdownBlock])
    case table([MarkdownBlock])

    var firstID: Int {
        switch self {
        case let .block(block): block.id
        case let .quote(blocks), let .table(blocks): blocks.first?.id ?? 0
        }
    }

    static func sections(from blocks: [MarkdownBlock]) -> [MarkdownSection] {
        var result: [MarkdownSection] = []
        var index = 0

        while index < blocks.count {
            if isTable(blocks[index].kind) {
                let containerID = blocks[index].containerID
                let end = runEnd(in: blocks, from: index) {
                    isTable($0.kind) && $0.containerID == containerID
                }
                result.append(.table(Array(blocks[index..<end])))
                index = end
            } else if blocks[index].isQuoted {
                let containerID = blocks[index].containerID
                let end = runEnd(in: blocks, from: index) {
                    $0.isQuoted && !isTable($0.kind) && $0.containerID == containerID
                }
                result.append(.quote(Array(blocks[index..<end])))
                index = end
            } else {
                result.append(.block(blocks[index]))
                index += 1
            }
        }

        return result
    }

    private static func runEnd(
        in blocks: [MarkdownBlock],
        from start: Int,
        while predicate: (MarkdownBlock) -> Bool
    ) -> Int {
        var end = start
        while end < blocks.count, predicate(blocks[end]) {
            end += 1
        }
        return end
    }

    private static func isTable(_ kind: MarkdownBlock.Kind) -> Bool {
        if case .tableRow = kind { return true }
        return false
    }
}
