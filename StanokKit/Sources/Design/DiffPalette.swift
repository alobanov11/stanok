import AppKit
import SwiftUI

enum DiffPalette {

    static let added = Color(nsColor: DiffPalette.tone(
        dark: (0.45, 0.79, 0.51),
        light: (0.13, 0.52, 0.24)
    ))

    static let removed = Color(nsColor: DiffPalette.tone(
        dark: (0.93, 0.51, 0.49),
        light: (0.74, 0.17, 0.16)
    ))
}

private extension DiffPalette {

    static func tone(
        dark: (CGFloat, CGFloat, CGFloat),
        light: (CGFloat, CGFloat, CGFloat)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let tone = appearance.isDark ? dark : light

            return NSColor(red: tone.0, green: tone.1, blue: tone.2, alpha: 1)
        }
    }
}
