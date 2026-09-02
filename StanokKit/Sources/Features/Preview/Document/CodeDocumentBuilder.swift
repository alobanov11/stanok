import AppKit

enum CodeDocumentBuilder {

    private struct Builder {

        let font: NSFont
        let changes: GitFileChanges
        let folded: Set<Int>
        let expanded: Set<Int>
        let visible: [Int]
        let text = NSMutableAttributedString()

        var rendered: [Int] = []

        mutating func append(_ tokens: [CodeToken], index: Int, position: Int) {
            let number = index + 1
            let gone = expanded.contains(number) ? changes.removed[number] : nil
            let follows = changes.kinds[number] == .removed

            if !follows { appendRemoved(gone, closing: false) }

            rendered.append(index)
            text.append(paragraph(tokens, index: index, position: position))

            if follows { appendTrailing(gone, position: position) }
        }

        mutating func appendGap() {
            rendered.append(-1)
            text.append(NSAttributedString(
                string: "⋯\n",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.tertiaryLabelColor,
                    PreviewDocument.gap: true
                ]
            ))
        }

        mutating func appendTrailing(_ gone: [String]?, position: Int) {
            guard let gone, !gone.isEmpty else { return }

            let closing = position == visible.count - 1

            if closing {
                text.append(NSAttributedString(string: "\n", attributes: [.font: font]))
            }

            appendRemoved(gone, closing: closing)
        }

        mutating func appendRemoved(_ gone: [String]?, closing: Bool) {
            guard let gone, !gone.isEmpty else { return }

            for (position, line) in gone.enumerated() {
                let last = closing && position == gone.count - 1
                rendered.append(-1)
                text.append(NSAttributedString(
                    string: last ? line : line + "\n",
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .backgroundColor: NSColor.systemRed.withAlphaComponent(0.18)
                    ]
                ))
            }
        }

        func paragraph(_ tokens: [CodeToken], index: Int, position: Int) -> NSAttributedString {
            let paragraph = NSMutableAttributedString()

            for token in tokens {
                paragraph.append(NSAttributedString(
                    string: token.text,
                    attributes: [
                        .font: font,
                        .foregroundColor: CodeTheme.nsColor(token.kind)
                    ]
                ))
            }

            if folded.contains(index) {
                paragraph.append(NSAttributedString(
                    string: " ⋯",
                    attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
                ))
            }

            if position < visible.count - 1 {
                paragraph.append(NSAttributedString(string: "\n", attributes: [.font: font]))
            }

            paragraph.addAttribute(
                PreviewDocument.sourceLine,
                value: index,
                range: NSRange(location: 0, length: paragraph.length)
            )

            return paragraph
        }
    }

    static func document(
        lines: [[CodeToken]],
        folds: CodeFoldMap,
        folded: Set<Int>,
        changes: GitFileChanges = .none,
        expanded: Set<Int> = [],
        font: NSFont,
        revision: String = "",
        onlyChanges: Bool = false
    ) -> PreviewDocument {
        let shown = folds.visibleLines(count: lines.count, folded: folded)
        let visible = onlyChanges
            ? Self.aroundChanges(shown, changes: changes, folds: folds, folded: folded)
            : shown
        var builder = Builder(
            font: font,
            changes: changes,
            folded: folded,
            expanded: expanded,
            visible: visible
        )

        var previous: Int?
        for (position, index) in visible.enumerated() {
            if let previous, index > previous + 1 { builder.appendGap() }

            builder.append(lines[index], index: index, position: position)
            previous = index
        }

        return PreviewDocument(text: builder.text, lines: builder.rendered, revision: revision)
    }

    // Почему: свёрнут может быть внешний блок при раскрытом внутреннем, идём по всей цепочке
    static func visibleLine(_ line: Int, folds: CodeFoldMap, folded: Set<Int>) -> Int {
        var current = line
        var shown = line

        while let owner = folds.owner(of: current) {
            if folded.contains(owner.header) { shown = owner.header }

            current = owner.header
        }

        return shown
    }

    // Почему: в ревью читают правку, а не файл, поэтому оставляем куски вокруг изменений
    static func aroundChanges(
        _ shown: [Int],
        changes: GitFileChanges,
        folds: CodeFoldMap = .empty,
        folded: Set<Int> = [],
        context: Int = 3
    ) -> [Int] {
        // Почему: изменение внутри свёрнутого блока иначе исчезает из ревью вместе с блоком
        let touched = Set(changes.kinds.keys).union(changes.removed.keys).map { number in
            visibleLine(number - 1, folds: folds, folded: folded)
        }
        guard !touched.isEmpty else { return shown }

        // Почему: проверка каждой строки по каждому окну — это миллионы сравнений на файл
        var covered: Set<Int> = []
        for line in touched {
            for index in (line - context)...(line + context) {
                covered.insert(index)
            }
        }

        return shown.filter { covered.contains($0) }
    }
}
