import SwiftUI

enum ListMetrics {

    enum Metric {

        static let markerSpacing: CGFloat = 8

        static let indentStep: CGFloat = 20

        static let markerCharWidthRatio: CGFloat = 0.62
    }

    static func indent(depth: Int) -> CGFloat {
        CGFloat(max(depth - 1, 0)) * Metric.indentStep
    }

    static func continuationLeading(depth: Int, markerWidth: CGFloat) -> CGFloat {
        indent(depth: depth) + markerWidth + Metric.markerSpacing
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
        case .bullet: "•"
        case let .numbered(ordinal, _): "\(ordinal)."
        default: ""
        }
    }

    static func isList(_ kind: MarkdownBlock.Kind) -> Bool {
        switch kind {
        case .bullet, .numbered, .continuation: true
        default: false
        }
    }

    static func markerWidths(for blocks: [MarkdownBlock], fontSize: Double) -> [Int: CGFloat] {
        var widths: [Int: CGFloat] = [:]
        var runStart: Int?

        for (index, block) in blocks.enumerated() {
            if isList(block.kind) {
                if runStart == nil { runStart = index }
            } else if let start = runStart {
                apply(&widths, blocks, start, index, fontSize)
                runStart = nil
            }
        }

        if let start = runStart { apply(&widths, blocks, start, blocks.count, fontSize) }
        return widths
    }

    private static func apply(
        _ widths: inout [Int: CGFloat],
        _ blocks: [MarkdownBlock],
        _ start: Int,
        _ end: Int,
        _ fontSize: Double
    ) {
        let longest = (start..<end)
            .map { markerText(blocks[$0].kind) }
            .max(by: { $0.count < $1.count }) ?? ""
        let charWidth = CGFloat(longest.count) * CGFloat(fontSize) * Metric.markerCharWidthRatio
        let width = max(charWidth, CGFloat(fontSize) * 0.5)

        for index in start..<end {
            widths[index] = width
        }
    }
}
