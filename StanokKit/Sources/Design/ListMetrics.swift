import SwiftUI

enum ListMetrics {

    static let indentStep: CGFloat = 18

    static func indent(depth: Int) -> CGFloat {
        CGFloat(depth + 1) * indentStep
    }

    static func depth(of kind: MarkdownBlock.Kind) -> Int {
        switch kind {
        case let .bullet(depth): depth
        case let .numbered(_, depth): depth
        case let .continuation(depth): depth
        default: 0
        }
    }

    static func markerText(_ kind: MarkdownBlock.Kind) -> String {
        switch kind {
        case .bullet: "\u{2022}"
        case let .numbered(ordinal, _): "\(ordinal)."
        default: ""
        }
    }
}
