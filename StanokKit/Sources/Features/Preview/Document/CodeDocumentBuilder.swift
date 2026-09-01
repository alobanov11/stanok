import AppKit

enum CodeDocumentBuilder {

    static func document(
        lines: [[CodeToken]],
        folds: CodeFoldMap,
        folded: Set<Int>,
        changes: GitFileChanges = .none,
        expanded: Set<Int> = [],
        font: NSFont,
        revision: String = ""
    ) -> PreviewDocument {
        let visible = folds.visibleLines(count: lines.count, folded: folded)
        let text = NSMutableAttributedString()

        func appendRemoved(_ gone: [String]) {
            for line in gone {
                text.append(NSAttributedString(
                    string: line + "\n",
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .backgroundColor: NSColor.systemRed.withAlphaComponent(0.18)
                    ]
                ))
            }
        }

        for (position, index) in visible.enumerated() {
            let number = index + 1
            let gone = expanded.contains(number) ? changes.removed[number] : nil
            let follows = changes.kinds[number] == .removed

            if let gone, !follows { appendRemoved(gone) }

            let paragraph = NSMutableAttributedString()

            for token in lines[index] {
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
            text.append(paragraph)

            if let gone, follows {
                if position == visible.count - 1 {
                    text.append(NSAttributedString(string: "\n", attributes: [.font: font]))
                }

                appendRemoved(gone)
            }
        }

        return PreviewDocument(text: text, revision: revision)
    }
}
