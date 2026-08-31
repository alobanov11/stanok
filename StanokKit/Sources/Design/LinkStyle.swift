import SwiftUI

enum LinkStyle {

    static let color = Color.accentColor

    static func styled(_ text: AttributedString) -> AttributedString {
        var styled = text
        for run in text.runs where run.link != nil {
            styled[run.range].foregroundColor = color
            styled[run.range].underlineStyle = .single
        }
        return styled
    }

    static func containsLink(_ text: AttributedString) -> Bool {
        text.runs.contains { $0.link != nil }
    }
}
