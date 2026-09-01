import AppKit

enum CodeDocumentBuilder {

    static func document(
        lines: [[CodeToken]],
        folds: CodeFoldMap,
        folded: Set<Int>,
        removed: [Int: [String]] = [:],
        expanded: Set<Int> = [],
        font: NSFont,
        revision: String = ""
    ) -> PreviewDocument {
        let visible = folds.visibleLines(count: lines.count, folded: folded)
        let text = NSMutableAttributedString()

        for (position, index) in visible.enumerated() {
            if expanded.contains(index + 1), let gone = removed[index + 1] {
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

            let paragraph = NSMutableAttributedString()

            for token in lines[index] {
                paragraph.append(NSAttributedString(
                    string: token.text,
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor(CodeTheme.color(token.kind))
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
        }

        return PreviewDocument(text: text, revision: revision)
    }
}
