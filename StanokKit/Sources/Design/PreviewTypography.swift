import SwiftUI

enum PreviewTypography {

    enum Keys {

        static let markdownFontSize = "previewMarkdownFontSize"

        static let markdownFontFamily = "previewMarkdownFontFamily"

        static let markdownLineSpacing = "previewMarkdownLineSpacing"

        static let codeFontSize = "previewCodeFontSize"

        static let codeFontFamily = "previewCodeFontFamily"
    }

    enum Defaults {

        static let markdownFontSize: Double = 13

        static let markdownFontFamily = ""

        static let markdownLineSpacing: Double = 4

        static let codeFontSize: Double = 12

        static let codeFontFamily = ""
    }

    enum Ranges {

        static let markdownFontSize: ClosedRange<Double> = 10...20

        static let markdownLineSpacing: ClosedRange<Double> = 0...14

        static let codeFontSize: ClosedRange<Double> = 10...20
    }

    static func markdownFont(size: Double, weight: Font.Weight = .regular, family: String) -> Font {
        guard !family.isEmpty else { return .system(size: size, weight: weight) }

        return .custom(family, size: size).weight(weight)
    }
}
