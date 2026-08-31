import Foundation

struct MarkdownBlock: Identifiable, Sendable {

    enum Kind: Sendable {

        case heading(Int)
        case paragraph
        case bullet(depth: Int)
        case numbered(ordinal: Int, depth: Int)
        case continuation(depth: Int)
        case code(lines: [[CodeToken]])
        case divider
        case tableRow(cells: [AttributedString], isHeader: Bool)
    }

    let id: Int
    let kind: Kind
    let text: AttributedString
    let isQuoted: Bool
    let containerID: Int?
}
