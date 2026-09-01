import AppKit

enum MarkdownDocumentBuilder {

    static func document(
        blocks: [MarkdownBlock],
        size: Double,
        family: String,
        lineSpacing: Double,
        codeSize: Double,
        codeFamily: String,
        revision: String = ""
    ) -> PreviewDocument {
        let text = NSMutableAttributedString()

        for (position, block) in blocks.enumerated() {
            if position > 0 {
                // Почему: перевод строки без стиля берёт системный шрифт и рвёт отступы
                text.append(NSAttributedString(
                    string: "\n",
                    attributes: [.font: PreviewTypographyFonts.reading(size: size, family: family)]
                ))
            }

            text.append(paragraph(
                block,
                size: size,
                family: family,
                lineSpacing: lineSpacing,
                codeSize: codeSize,
                codeFamily: codeFamily
            ))
        }

        return PreviewDocument(text: text, lines: [], revision: revision)
    }
}

private extension MarkdownDocumentBuilder {

    static func paragraph(
        _ block: MarkdownBlock,
        size: Double,
        family: String,
        lineSpacing: Double,
        codeSize: Double,
        codeFamily: String
    ) -> NSAttributedString {
        switch block.kind {
        case let .heading(level):
            return heading(
                block.text,
                font: PreviewTypographyFonts.reading(
                    size: headingSize(level, base: size),
                    family: family,
                    weight: level <= 2 ? .bold : .semibold
                ),
                spacing: lineSpacing
            )

        case .paragraph:
            return styled(
                block.text,
                font: PreviewTypographyFonts.reading(size: size, family: family),
                spacing: lineSpacing,
                indent: block.isQuoted ? ListMetrics.indent(depth: 1) : 0,
                quoted: block.isQuoted
            )

        case .bullet, .numbered:
            let marker = ListMetrics.markerText(block.kind)
            let indent = ListMetrics.indent(depth: ListMetrics.depth(of: block.kind))
            let text = NSMutableAttributedString(
                string: "\(marker)\t",
                attributes: [
                    .font: PreviewTypographyFonts.reading(size: size, family: family),
                    .foregroundColor: NSColor.tertiaryLabelColor
                ]
            )
            text.append(styled(
                block.text,
                font: PreviewTypographyFonts.reading(size: size, family: family),
                spacing: lineSpacing,
                indent: indent
            ))
            text.addAttribute(
                .paragraphStyle,
                value: listStyle(spacing: lineSpacing, indent: indent),
                range: NSRange(location: 0, length: text.length)
            )
            return text

        case let .continuation(depth):
            return styled(
                block.text,
                font: PreviewTypographyFonts.reading(size: size, family: family),
                spacing: lineSpacing,
                indent: ListMetrics.indent(depth: depth)
            )

        case let .code(lines):
            return code(lines, size: codeSize, family: codeFamily)

        case .divider:
            return NSAttributedString(
                string: String(repeating: "─", count: 24),
                attributes: [
                    .font: PreviewTypographyFonts.reading(size: size, family: family),
                    .foregroundColor: NSColor.separatorColor
                ]
            )

        case let .tableRow(cells, isHeader):
            return row(
                cells,
                isHeader: isHeader,
                font: PreviewTypographyFonts.code(size: codeSize, family: codeFamily),
                spacing: lineSpacing
            )
        }
    }

    // Почему: таблица держится на табуляциях, иначе ячейки склеиваются в одну строку
    static func row(
        _ cells: [AttributedString],
        isHeader: Bool,
        font: NSFont,
        spacing: Double
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        style.defaultTabInterval = 140
        style.tabStops = (1...max(cells.count, 1)).map {
            NSTextTab(textAlignment: .left, location: CGFloat($0) * 140)
        }

        let resolved = isHeader
            ? NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.bold), size: font.pointSize)
            ?? font
            : font

        let text = NSMutableAttributedString(
            string: cells.map { String($0.characters) }.joined(separator: "\t"),
            attributes: [
                .font: resolved,
                .foregroundColor: isHeader ? NSColor.labelColor : NSColor.secondaryLabelColor,
                .paragraphStyle: style
            ]
        )

        return text
    }

    static func code(_ lines: [[CodeToken]], size: Double, family: String) -> NSAttributedString {
        let font = PreviewTypographyFonts.code(size: size, family: family)
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 14
        style.headIndent = 14
        style.paragraphSpacingBefore = 10
        style.paragraphSpacing = 10

        let text = NSMutableAttributedString()
        // Почему: фон рисуется по глифам, поэтому строки добиваем до общей ширины
        let width = lines.map { $0.reduce(0) { $0 + $1.text.count } }.max() ?? 0

        for (position, tokens) in lines.enumerated() {
            var filled = 0

            for token in tokens {
                filled += token.text.count
                text.append(NSAttributedString(
                    string: token.text,
                    attributes: [
                        .font: font,
                        .foregroundColor: CodeTheme.nsColor(token.kind)
                    ]
                ))
            }

            if width > filled {
                text.append(NSAttributedString(
                    string: String(repeating: " ", count: width - filled),
                    attributes: [.font: font]
                ))
            }

            if position < lines.count - 1 {
                text.append(NSAttributedString(string: "\n", attributes: [.font: font]))
            }
        }

        text.addAttributes(
            // Почему: тёмная подложка сливалась с фоном окна, блок выглядел обычным текстом
            [
                .paragraphStyle: style,
                .backgroundColor: NSColor.white.withAlphaComponent(0.07)
            ],
            range: NSRange(location: 0, length: text.length)
        )
        return text
    }

    // Почему: заголовку нужен воздух сверху, иначе он липнет к предыдущему абзацу
    static func heading(
        _ text: AttributedString,
        font: NSFont,
        spacing: Double
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        style.paragraphSpacingBefore = font.pointSize * 0.9
        style.paragraphSpacing = 2

        return MarkdownInlineText.attributed(
            text,
            font: font,
            codeFont: .monospacedSystemFont(ofSize: font.pointSize * 0.9, weight: .regular),
            style: style
        )
    }

    static func listStyle(spacing: Double, indent: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        style.headIndent = indent
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]

        return style
    }

    static func styled(
        _ text: AttributedString,
        font: NSFont,
        spacing: Double,
        indent: CGFloat,
        quoted: Bool = false
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        style.paragraphSpacingBefore = 4
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent + 18)]

        let result = MarkdownInlineText.attributed(
            text,
            font: font,
            codeFont: .monospacedSystemFont(ofSize: font.pointSize * 0.94, weight: .regular),
            style: style
        )

        guard quoted else { return result }

        let quote = NSMutableAttributedString(attributedString: result)
        quote.addAttribute(
            .foregroundColor,
            value: NSColor.secondaryLabelColor,
            range: NSRange(location: 0, length: quote.length)
        )

        return quote
    }

    static func headingSize(_ level: Int, base: Double) -> Double {
        switch level {
        case 1: base * 1.6
        case 2: base * 1.3
        case 3: base * 1.15
        case 4: base * 1.05
        default: base
        }
    }
}
