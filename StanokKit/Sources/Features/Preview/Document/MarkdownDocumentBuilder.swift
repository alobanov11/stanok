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
                text.append(NSAttributedString(string: "\n"))
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

        return PreviewDocument(text: text, revision: revision)
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
            return styled(
                block.text,
                font: PreviewTypographyFonts.reading(
                    size: headingSize(level, base: size),
                    family: family,
                    weight: level <= 2 ? .bold : .semibold
                ),
                spacing: lineSpacing,
                indent: 0
            )

        case .paragraph:
            return styled(
                block.text,
                font: PreviewTypographyFonts.reading(size: size, family: family),
                spacing: lineSpacing,
                indent: 0
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

        case .tableRow:
            return styled(
                block.text,
                font: PreviewTypographyFonts.code(size: codeSize, family: codeFamily),
                spacing: lineSpacing,
                indent: 0
            )
        }
    }

    static func code(_ lines: [[CodeToken]], size: Double, family: String) -> NSAttributedString {
        let font = PreviewTypographyFonts.code(size: size, family: family)
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 12
        style.headIndent = 12
        style.paragraphSpacingBefore = 6
        style.paragraphSpacing = 6

        let text = NSMutableAttributedString()

        for (position, tokens) in lines.enumerated() {
            for token in tokens {
                text.append(NSAttributedString(
                    string: token.text,
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor(CodeTheme.color(token.kind))
                    ]
                ))
            }

            if position < lines.count - 1 {
                text.append(NSAttributedString(string: "\n", attributes: [.font: font]))
            }
        }

        text.addAttributes(
            [
                .paragraphStyle: style,
                .backgroundColor: NSColor.black.withAlphaComponent(0.22)
            ],
            range: NSRange(location: 0, length: text.length)
        )
        return text
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
        indent: CGFloat
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent + 18)]

        return MarkdownInlineText.attributed(
            text,
            font: font,
            codeFont: .monospacedSystemFont(ofSize: font.pointSize * 0.94, weight: .regular),
            style: style
        )
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
