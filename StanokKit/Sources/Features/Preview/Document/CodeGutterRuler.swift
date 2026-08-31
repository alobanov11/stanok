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
        guard let source, let text = clientView as? NSTextView else { return }

        let numbers: [NSAttributedString.Key: Any] = [
            .font: source.font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        enumerateVisibleFragments(from: rect.minY, in: text) { line, top, height in
            let label = NSAttributedString(string: "\(line + 1)", attributes: numbers)
            let size = label.size()
            label.draw(at: NSPoint(x: source.width + Metric.gap - size.width, y: top))

            if source.folds.fold(startingAt: line) != nil {
                drawChevron(
                    at: NSPoint(x: source.width + Metric.gap * 1.5, y: top + height / 2),
                    collapsed: source.folded.contains(line)
                )
            }

            guard let change = source.changes[line + 1] else { return top < rect.maxY }

            NSColor.controlAccentColor.setFill()
            NSRect(
                x: ruleThickness - Metric.ribbon - 2,
                y: top,
                width: Metric.ribbon,
                height: change == .removed ? 2 : height
            ).fill()

            return top < rect.maxY
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
        guard let text = clientView as? NSTextView else { return nil }

        var found: Int?

        enumerateVisibleFragments(from: y, in: text) { line, top, height in
            guard top <= y, top + height > y else { return top <= y }

            found = line
            return false
        }

        return found
    }

    func enumerateVisibleFragments(
        from y: CGFloat,
        in text: NSTextView,
        body: (Int, CGFloat, CGFloat) -> Bool
    ) {
        guard let layout = text.textLayoutManager else { return }

        let start = convert(NSPoint(x: 0, y: y), to: text).y - text.textContainerOrigin.y
        guard let first = layout.textLayoutFragment(for: NSPoint(x: 0, y: max(start, 0)))
        else { return }

        layout.enumerateTextLayoutFragments(from: first.rangeInElement.location) { fragment in
            let frame = fragment.layoutFragmentFrame
            let top = convert(
                NSPoint(x: 0, y: text.textContainerOrigin.y + frame.minY),
                from: text
            ).y

            guard let line = sourceLine(of: fragment) else { return true }

            return body(line, top, frame.height)
        }
    }
}
