import AppKit

final class CodeGutterRuler: NSRulerView {

    struct Source {

        let changes: [Int: LineChange]
        let folds: CodeFoldMap
        let folded: Set<Int>
        let font: NSFont
        let width: CGFloat
        let toggle: (Int) -> Void
    }

    private enum Metric {

        static let ribbon: CGFloat = 3
        static let gap: CGFloat = 8
        static let chevron: CGFloat = 9
    }

    var source: Source? {
        didSet {
            ruleThickness = source.map {
                $0.width + Metric.ribbon + Metric.chevron + Metric.gap * 2
            } ?? 0
        }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let source,
            let text = clientView as? NSTextView,
            let layout = text.textLayoutManager,
            let viewport = layout.textViewportLayoutController.viewportRange
        else { return }

        let numbers: [NSAttributedString.Key: Any] = [
            .font: source.font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        layout.enumerateTextLayoutFragments(from: viewport.location) { fragment in
            let frame = fragment.layoutFragmentFrame
            let origin = convert(
                NSPoint(x: 0, y: text.textContainerOrigin.y + frame.minY),
                from: text
            )

            guard origin.y < rect.maxY + frame.height else { return false }
            guard origin.y + frame.height > rect.minY else { return true }

            let line = sourceLine(of: fragment)
            guard let line else { return true }

            let label = NSAttributedString(string: "\(line + 1)", attributes: numbers)
            let size = label.size()
            label.draw(at: NSPoint(x: source.width + Metric.gap - size.width, y: origin.y))

            if source.folds.fold(startingAt: line) != nil {
                drawChevron(
                    at: NSPoint(x: source.width + Metric.gap, y: origin.y + frame.height / 2),
                    collapsed: source.folded.contains(line)
                )
            }

            if let change = source.changes[line + 1] {
                NSColor.controlAccentColor.setFill()
                NSRect(
                    x: source.width + Metric.gap + Metric.chevron + Metric.gap - Metric.ribbon,
                    y: origin.y,
                    width: Metric.ribbon,
                    height: change == .removed ? 2 : frame.height
                ).fill()
            }

            return true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        guard let source, let line = line(at: point.y), source.folds.fold(startingAt: line) != nil
        else { return super.mouseDown(with: event) }

        source.toggle(line)
    }

    private func sourceLine(of fragment: NSTextLayoutFragment) -> Int? {
        guard let paragraph = fragment.textElement as? NSTextParagraph else { return nil }

        return paragraph.attributedString.attribute(
            PreviewDocument.sourceLine,
            at: 0,
            effectiveRange: nil
        ) as? Int
    }
}

private extension CodeGutterRuler {

    func drawChevron(at point: NSPoint, collapsed: Bool) {
        let path = NSBezierPath()
        let size = Metric.chevron / 2

        if collapsed {
            path.move(to: NSPoint(x: point.x, y: point.y - size))
            path.line(to: NSPoint(x: point.x + size, y: point.y))
            path.line(to: NSPoint(x: point.x, y: point.y + size))
        } else {
            path.move(to: NSPoint(x: point.x - size, y: point.y - size / 2))
            path.line(to: NSPoint(x: point.x + size, y: point.y - size / 2))
            path.line(to: NSPoint(x: point.x, y: point.y + size))
        }

        NSColor.tertiaryLabelColor.setFill()
        path.fill()
    }

    func line(at y: CGFloat) -> Int? {
        guard
            let text = clientView as? NSTextView,
            let layout = text.textLayoutManager,
            let viewport = layout.textViewportLayoutController.viewportRange
        else { return nil }

        var found: Int?

        layout.enumerateTextLayoutFragments(from: viewport.location) { fragment in
            let frame = fragment.layoutFragmentFrame
            let origin = convert(
                NSPoint(x: 0, y: text.textContainerOrigin.y + frame.minY),
                from: text
            )

            guard origin.y <= y else { return false }
            guard origin.y + frame.height > y else { return true }

            found = sourceLine(of: fragment)
            return false
        }

        return found
    }
}
