import Foundation

enum BlockMargins {

    static func gap(
        before current: MarkdownBlock.Kind,
        after previous: MarkdownBlock.Kind,
        base: Double
    ) -> Double {
        max(after(previous, base: base), before(current, base: base))
    }

    static func before(_ kind: MarkdownBlock.Kind, base: Double) -> Double {
        switch kind {
        case let .heading(level): headingBefore(level, base: base)
        case .paragraph: base * 0.75
        case .bullet, .numbered: base * 0.28
        case .continuation: base * 0.55
        case .code: base * 1.15
        case .divider: base * 1.25
        case .tableRow: 0
        }
    }

    static func after(_ kind: MarkdownBlock.Kind, base: Double) -> Double {
        switch kind {
        case .heading: base * 0.5
        case .paragraph: base * 0.75
        case .bullet, .numbered: base * 0.28
        case .continuation: base * 0.55
        case .code: base * 1.15
        case .divider: base * 1.25
        case .tableRow: 0
        }
    }

    private static func headingBefore(_ level: Int, base: Double) -> Double {
        switch level {
        case 1, 2: base * 1.625
        case 3: base * 1.25
        case 4: base * 1.0
        default: base * 0.85
        }
    }
}
