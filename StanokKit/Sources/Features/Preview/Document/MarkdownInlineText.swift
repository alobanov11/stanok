import AppKit

enum MarkdownInlineText {

    static func attributed(
        _ text: AttributedString,
        font: NSFont,
        codeFont: NSFont,
        style: NSParagraphStyle
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for run in text.runs {
            let intent = run.inlinePresentationIntent
            var attributes: [NSAttributedString.Key: Any] = [
                .font: resolved(intent, font: font, codeFont: codeFont),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style
            ]

            if intent?.contains(.code) == true {
                attributes[.backgroundColor] = NSColor.white.withAlphaComponent(0.08)
            }

            if let link = run.link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            if intent?.contains(.strikethrough) == true {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            result.append(NSAttributedString(
                string: String(text[run.range].characters),
                attributes: attributes
            ))
        }

        return result
    }
}

private extension MarkdownInlineText {

    static func resolved(
        _ intent: InlinePresentationIntent?,
        font: NSFont,
        codeFont: NSFont
    ) -> NSFont {
        guard let intent else { return font }

        if intent.contains(.code) { return codeFont }

        var traits: NSFontDescriptor.SymbolicTraits = []
        if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
        if intent.contains(.emphasized) { traits.insert(.italic) }

        guard !traits.isEmpty else { return font }

        let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }
}
