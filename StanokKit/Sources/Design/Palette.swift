import AppKit
import SwiftUI

// Почему: накладки поверх материала должны менять сторону вместе с темой, иначе текст пропадает
enum Palette {

    enum NS {

        static let codeFill = Palette.tint(dark: 0.07, light: 0.05)
        static let inlineCodeFill = Palette.tint(dark: 0.08, light: 0.06)
        static let ribbon = Palette.tint(dark: 0.55, light: 0.45)
        static let ribbonDim = Palette.tint(dark: 0.14, light: 0.12)
    }

    static let cardFill = Color(nsColor: Palette.tint(dark: 0.05, light: 0.05))
    static let hoverFill = Color(nsColor: Palette.tint(dark: 0.08, light: 0.06))
    static let selectionFill = Color(nsColor: Palette.tint(dark: 0.12, light: 0.10))
    static let stroke = Color(nsColor: Palette.tint(dark: 0.08, light: 0.14))
    static let strokeStrong = Color(nsColor: Palette.tint(dark: 0.16, light: 0.24))
    static let inset = Color(nsColor: Palette.shade(dark: 0.18, light: 0.05))
    static let insetStrong = Color(nsColor: Palette.shade(dark: 0.22, light: 0.07))
    static let shadow = Color(nsColor: Palette.shade(dark: 0.28, light: 0.16))
    static let raised = Color(nsColor: Palette.tint(dark: 0.10, light: 0.35))
    static let edge = Color(nsColor: Palette.tint(dark: 0.28, light: 0.45))
}

private extension Palette {

    static func tint(dark: CGFloat, light: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.isDark
                ? NSColor.white.withAlphaComponent(dark)
                : NSColor.black.withAlphaComponent(light)
        }
    }

    static func shade(dark: CGFloat, light: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            NSColor.black.withAlphaComponent(appearance.isDark ? dark : light)
        }
    }
}
