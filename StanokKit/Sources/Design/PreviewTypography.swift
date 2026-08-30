import Foundation

enum PreviewTypography {

    enum Keys {

        static let markdownFontSize = "previewMarkdownFontSize"

        static let markdownLineSpacing = "previewMarkdownLineSpacing"

        static let codeFontSize = "previewCodeFontSize"

        static let codeFontFamily = "previewCodeFontFamily"
    }

    enum Defaults {

        static let markdownFontSize: Double = 13

        static let markdownLineSpacing: Double = 4

        static let codeFontSize: Double = 12

        static let codeFontFamily = ""
    }

    static let markdownFontSizeRange: ClosedRange<Double> = 10...20

    static let markdownLineSpacingRange: ClosedRange<Double> = 0...14

    static let codeFontSizeRange: ClosedRange<Double> = 10...20
}
