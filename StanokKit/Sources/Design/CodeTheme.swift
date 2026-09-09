import AppKit
import SwiftUI

enum CodeTheme {

    private enum Tone {

        static let string = CodeTheme.pair(dark: (0.55, 0.79, 0.55), light: (0.11, 0.45, 0.20))
        static let number = CodeTheme.pair(dark: (0.78, 0.66, 0.94), light: (0.40, 0.26, 0.68))
        static let keyword = CodeTheme.pair(dark: (0.94, 0.53, 0.69), light: (0.72, 0.14, 0.38))
    }

    static func nsColor(_ kind: CodeToken.Kind) -> NSColor {
        switch kind {
        case .plain: .labelColor
        case .comment: .secondaryLabelColor
        case .string: Tone.string
        case .number: Tone.number
        case .keyword: Tone.keyword
        }
    }

    static func font(size: Double, family: String) -> Font {
        family.isEmpty
            ? .system(size: size, design: .monospaced)
            : .custom(family, size: size)
    }

    static func color(_ kind: CodeToken.Kind) -> Color {
        switch kind {
        case .plain: .primary
        case .comment: .secondary
        default: Color(nsColor: nsColor(kind))
        }
    }
}

private extension CodeTheme {

    // Почему: пастель читается на тёмном фоне, на светлом те же оттенки сливаются с бумагой
    static func pair(
        dark: (CGFloat, CGFloat, CGFloat),
        light: (CGFloat, CGFloat, CGFloat)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let tone = appearance.isDark ? dark : light

            return NSColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 1)
        }
    }
}
