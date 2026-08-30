import Foundation

enum MarkdownParser {

    private struct Leaf {

        let components: [PresentationIntent.IntentType]

        let text: AttributedString
    }

    private struct Row {

        let identity: Int

        let isHeader: Bool
    }

    static func blocks(from markdown: String, baseURL: URL? = nil) -> [MarkdownBlock] {
        guard
            let parsed = try? AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                ),
                baseURL: baseURL
            )
        else { return [] }

        return fold(leaves(of: parsed))
    }

    private static func leaves(of parsed: AttributedString) -> [Leaf] {
        var leaves: [Leaf] = []
        var text = AttributedString()
        var components: [PresentationIntent.IntentType] = []
        var identity: [Int] = []
        var started = false

        for run in parsed.runs {
            let current = run.presentationIntent?.components ?? []
            let key = current.map(\.identity)

            if started, key != identity {
                leaves.append(Leaf(components: components, text: text))
                text = AttributedString()
            }

            identity = key
            components = current
            started = true
            text.append(parsed[run.range])
        }

        if started { leaves.append(Leaf(components: components, text: text)) }
        return leaves
    }

    private static func fold(_ leaves: [Leaf]) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var cells: [AttributedString] = []
        var row: Row?
        var lastItem: Int?

        for leaf in leaves {
            if let current = rowInfo(leaf.components) {
                if current.identity != row?.identity {
                    flush(&blocks, &cells, row)
                }
                row = current
                cells.append(leaf.text)
                continue
            }

            flush(&blocks, &cells, row)
            row = nil

            if let block = block(blocks.count, leaf, &lastItem) {
                blocks.append(contentsOf: split(block, from: blocks.count))
            }
        }

        flush(&blocks, &cells, row)
        return blocks
    }

    private static func lines(of text: AttributedString) -> [AttributedString] {
        var parts: [AttributedString] = []
        var start = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let next = text.characters.index(after: index)
            if text.characters[index].isNewline {
                parts.append(AttributedString(text[start..<index]))
                start = next
            }
            index = next
        }

        parts.append(AttributedString(text[start..<text.endIndex]))
        return parts.filter { !$0.characters.isEmpty }
    }

    private static func split(_ block: MarkdownBlock, from id: Int) -> [MarkdownBlock] {
        switch block.kind {
        case .code, .divider, .tableRow: return [block]
        default: break
        }

        let parts = lines(of: block.text)
        guard parts.count > 1 else { return [block] }

        let tail = continuation(after: block.kind)
        return parts.enumerated().map { offset, text in
            MarkdownBlock(
                id: id + offset,
                kind: offset == 0 ? block.kind : tail,
                text: text,
                isQuoted: block.isQuoted
            )
        }
    }

    private static func continuation(after kind: MarkdownBlock.Kind) -> MarkdownBlock.Kind {
        switch kind {
        case let .bullet(depth): .continuation(depth: depth)
        case let .numbered(_, depth): .continuation(depth: depth)
        case let .continuation(depth): .continuation(depth: depth)
        default: .paragraph
        }
    }

    private static func flush(
        _ blocks: inout [MarkdownBlock],
        _ cells: inout [AttributedString],
        _ row: Row?
    ) {
        guard !cells.isEmpty, let row else { return }

        blocks.append(MarkdownBlock(
            id: blocks.count,
            kind: .tableRow(cells: cells, isHeader: row.isHeader),
            text: AttributedString(),
            isQuoted: false
        ))
        cells = []
    }

    private static func rowInfo(_ components: [PresentationIntent.IntentType]) -> Row? {
        var isCell = false
        for component in components {
            switch component.kind {
            case .tableCell: isCell = true
            case .tableHeaderRow:
                return isCell ? Row(identity: component.identity, isHeader: true) : nil
            case .tableRow:
                return isCell ? Row(identity: component.identity, isHeader: false) : nil
            default: continue
            }
        }

        return nil
    }

    private static func block(
        _ id: Int,
        _ leaf: Leaf,
        _ lastItem: inout Int?
    ) -> MarkdownBlock? {
        let quoted = leaf.components.contains { component in
            if case .blockQuote = component.kind { return true }
            return false
        }

        let kind = kind(of: leaf.components, lastItem: &lastItem, text: leaf.text)
        if case .divider = kind {
            return MarkdownBlock(id: id, kind: .divider, text: AttributedString(), isQuoted: quoted)
        }

        return MarkdownBlock(id: id, kind: kind, text: leaf.text, isQuoted: quoted)
    }

    private static func kind(
        of components: [PresentationIntent.IntentType],
        lastItem: inout Int?,
        text: AttributedString
    ) -> MarkdownBlock.Kind {
        for (offset, component) in components.enumerated() {
            switch component.kind {
            case let .header(level):
                lastItem = nil
                return .heading(level)

            case let .codeBlock(language):
                lastItem = nil
                let source = String(text.characters)
                return .code(lines: CodeHighlighter.lines(source, language: language))

            case .thematicBreak:
                lastItem = nil
                return .divider

            case let .listItem(ordinal):
                return listKind(components, from: offset, ordinal: ordinal, lastItem: &lastItem)

            default:
                continue
            }
        }

        lastItem = nil
        return .paragraph
    }

    private static func listKind(
        _ components: [PresentationIntent.IntentType],
        from offset: Int,
        ordinal: Int,
        lastItem: inout Int?
    ) -> MarkdownBlock.Kind {
        let identity = components[offset].identity
        let depth = components.count(where: { component in
            switch component.kind {
            case .orderedList, .unorderedList: true
            default: false
            }
        })

        defer { lastItem = identity }
        if lastItem == identity { return .continuation(depth: depth) }

        var ordered = false
        if offset + 1 < components.count, case .orderedList = components[offset + 1].kind {
            ordered = true
        }

        return ordered ? .numbered(ordinal: ordinal, depth: depth) : .bullet(depth: depth)
    }
}
