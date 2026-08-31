import AppKit

enum CodeDocumentBuilder {

    static func document(
        lines: [[CodeToken]],
        folds: CodeFoldMap,
        folded: Set<Int>,
        font: NSFont
    ) -> PreviewDocument {
        let visible = folds.visibleLines(count: lines.count, folded: folded)
        let text = NSMutableAttributedString()

        for (position, index) in visible.enumerated() {
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

        return PreviewDocument(text: text, lines: visible, folds: folds)
    }
}
