import Foundation
import Markdown

struct MarkdownBlockBuilder {

    private(set) var blocks: [MarkdownBlock] = []

    private var quotes = 0
    private var container: Int?

    private let baseURL: URL?

    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    mutating func append(_ markup: any Markup, depth: Int = 0) {
        switch markup {
        case let heading as Heading:
            add(.heading(heading.level), text: inline(heading))

        case let paragraph as Paragraph:
            add(depth > 0 ? .continuation(depth: depth) : .paragraph, text: inline(paragraph))

        case let block as CodeBlock:
            add(code(block.code, language: block.language))

        case let html as HTMLBlock:
            add(code(html.rawHTML, language: "html"))

        case is ThematicBreak:
            add(.divider)

        case let list as UnorderedList:
            appendItems(list.listItems, ordinal: nil, depth: depth)

        case let list as OrderedList:
            appendItems(list.listItems, ordinal: Int(list.startIndex), depth: depth)

        case let quote as BlockQuote:
            appendQuote(quote, depth: depth)

        case let table as Table:
            appendTable(table)

        default:
            for child in markup.children {
                append(child, depth: depth)
            }
        }
    }
}

private extension MarkdownBlockBuilder {

    mutating func add(_ kind: MarkdownBlock.Kind, text: AttributedString = AttributedString()) {
        blocks.append(
            MarkdownBlock(
                id: blocks.count,
                kind: kind,
                text: text,
                isQuoted: quotes > 0,
                containerID: container
            )
        )
    }

    mutating func appendItems(_ items: some Sequence<ListItem>, ordinal: Int?, depth: Int) {
        for (offset, item) in items.enumerated() {
            appendItem(item, ordinal: ordinal.map { $0 + offset }, depth: depth + 1)
        }
    }

    mutating func appendItem(_ item: ListItem, ordinal: Int?, depth: Int) {
        var isFirst = true

        for child in item.children {
            guard isFirst, let paragraph = child as? Paragraph else {
                append(child, depth: depth)
                continue
            }

            isFirst = false
            add(
                ordinal.map { .numbered(ordinal: $0, depth: depth) } ?? .bullet(depth: depth),
                text: checkbox(item) + inline(paragraph)
            )
        }
    }

    // Почему: чекбокс живёт в самом пункте, а рисуется как часть его текста
    func checkbox(_ item: ListItem) -> AttributedString {
        switch item.checkbox {
        case .checked: AttributedString("☑ ")
        case .unchecked: AttributedString("☐ ")
        case .none: AttributedString()
        }
    }

    mutating func appendQuote(_ quote: BlockQuote, depth: Int) {
        let previous = container
        quotes += 1
        container = blocks.count

        for child in quote.children {
            append(child, depth: depth)
        }

        quotes -= 1
        container = previous
    }

    mutating func appendTable(_ table: Table) {
        let previous = container
        container = blocks.count

        add(.tableRow(cells: cells(of: table.head.cells), isHeader: true))

        for row in table.body.rows {
            add(.tableRow(cells: cells(of: row.cells), isHeader: false))
        }

        container = previous
    }

    func cells(of cells: some Sequence<Table.Cell>) -> [AttributedString] {
        cells.map { inline($0) }
    }

    func code(_ source: String, language: String?) -> MarkdownBlock.Kind {
        let text = source.hasSuffix("\n") ? String(source.dropLast()) : source

        return .code(lines: CodeHighlighter.lines(text, language: language ?? ""))
    }

    func inline(_ markup: any Markup) -> AttributedString {
        MarkdownInline.text(of: markup, baseURL: baseURL)
    }
}
