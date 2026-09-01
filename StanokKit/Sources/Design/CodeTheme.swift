import AppKit
import SwiftUI

enum CodeTheme {

    private static let cachedColors: [CodeToken.Kind: NSColor] = [
        .plain: NSColor(color(.plain)),
        .comment: NSColor(color(.comment)),
        .string: NSColor(color(.string)),
        .number: NSColor(color(.number)),
        .keyword: NSColor(color(.keyword))
    ]

    static func nsColor(_ kind: CodeToken.Kind) -> NSColor {
        cachedColors[kind] ?? .textColor
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
        case .string: Color(red: 0.55, green: 0.79, blue: 0.55)
        case .number: Color(red: 0.78, green: 0.66, blue: 0.94)
        case .keyword: Color(red: 0.94, green: 0.53, blue: 0.69)
        }
    }
}
