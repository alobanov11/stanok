import SwiftUI

enum MarkdownInlineStyle {

    static func resolved(
        _ text: AttributedString,
        size: Double,
        family: String
    ) -> AttributedString {
        var styled = text

        for run in text.runs {
            let intent = run.inlinePresentationIntent
            styled[run.range].font = font(for: intent, size: size, family: family)
            styled[run.range].inlinePresentationIntent = nil
        }

        return styled
    }

    private static func font(
        for intent: InlinePresentationIntent?,
        size: Double,
        family: String
    ) -> Font {
        guard let intent else {
            return PreviewTypography.markdownFont(size: size, family: family)
        }

        if intent.contains(.code) { return .system(size: size * 0.94, design: .monospaced) }

        let weight: Font.Weight = intent.contains(.stronglyEmphasized) ? .bold : .regular
        let base = PreviewTypography.markdownFont(size: size, weight: weight, family: family)

        return intent.contains(.emphasized) ? base.italic() : base
    }
}
