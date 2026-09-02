import AppKit

final class CodeGutterRuler: NSRulerView {

    struct Source {

        let changes: GitFileChanges
        let folds: CodeFoldMap
        let folded: Set<Int>
        let expanded: Set<Int>
        let font: NSFont
        let width: CGFloat
        let fold: (Int) -> Void
        let showChange: (Int) -> Void
    }

    private enum Metric {

        static let ribbon: CGFloat = 5
        static let ribbonGap: CGFloat = 7
        static let gap: CGFloat = 8
        static let foldGap: CGFloat = 10
        static let chevron: CGFloat = 9
    }

    var stamp: String {
        guard let source else { return "" }

        return [
            "\(source.changes.digest)",
            "\(source.folded.count)", "\(source.expanded.count)",
            "\(source.width)", source.font.fontName, "\(source.font.pointSize)"
        ].joined(separator: "|")
    }

    var source: Source? {
        didSet {
            anchors = Self.anchors(of: source)

            let thickness = source.map {
                $0.width + Metric.gap + Metric.foldGap + Metric.chevron
                    + Metric.gap + Metric.ribbon + Metric.ribbonGap
            } ?? 0

            guard thickness != ruleThickness else { return }

            ruleThickness = thickness
            // Почему: без перекладки текст остаётся под гаттером и первые символы срезаны
            scrollView?.tile()
        }
    }

    private var anchors: [Int: Int] = [:]
    private var hovered: Int?
    private var tracking: NSTrackingArea?

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let source, let text = clientView as? NSTextView else { return }

        let numbers: [NSAttributedString.Key: Any] = [
            .font: source.font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        enumerateVisibleFragments(from: rect.minY, in: text) { line, top, height, isGap in
            // Почему: у раскрытых удалённых строк нет номера, но полоса им нужна целиком
            guard let line else {
                if !isGap { drawRemovedRibbon(top: top, height: height) }

                return top < rect.maxY
            }

            let label = NSAttributedString(string: "\(line + 1)", attributes: numbers)
            let size = label.size()
            label.draw(at: NSPoint(x: source.width + Metric.gap - size.width, y: top))

            drawFoldRibbon(for: line, top: top, height: height, source: source)
            drawChangeRibbon(for: line, top: top, height: height, source: source)

            return top < rect.maxY
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let line = line(at: point.y)
        let owner = line.flatMap {
            source?.folds.fold(startingAt: $0)?.header ?? source?.folds.owner(of: $0)?.header
        }
        let next = isInFoldColumn(point.x) ? owner : nil

        guard next != hovered else { return }

        hovered = next
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        guard hovered != nil else { return }

        hovered = nil
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let tracking { removeTrackingArea(tracking) }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        guard let source, let line = line(at: point.y) else { return super.mouseDown(with: event) }

        if isInFoldColumn(point.x) {
            let fold = source.folds.fold(startingAt: line) ?? source.folds.owner(of: line)
            guard let fold else { return super.mouseDown(with: event) }

            source.fold(fold.header)
            return
        }

        guard let anchor = removalAnchor(for: line, source: source) else {
            return super.mouseDown(with: event)
        }

        source.showChange(anchor)
    }

    private func isGap(_ fragment: NSTextLayoutFragment) -> Bool {
        guard let paragraph = fragment.textElement as? NSTextParagraph else { return false }

        return paragraph.attributedString.attribute(
            PreviewDocument.gap,
            at: 0,
            effectiveRange: nil
        ) as? Bool ?? false
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

    func foldColumn(_ source: Source) -> CGFloat {
        source.width + Metric.gap + Metric.foldGap
    }

    func isInFoldColumn(_ x: CGFloat) -> Bool {
        guard let source else { return false }

        return x > foldColumn(source) && x < foldColumn(source) + Metric.chevron
    }

    // Почему: удаления привязаны к одной строке блока, а кликают по любой его полосе
    func removalAnchor(for line: Int, source: Source) -> Int? {
        anchors[line + 1]
    }

    // Почему: искать якорь на каждую видимую строку каждого кадра — это тысячи обходов
    static func anchors(of source: Source?) -> [Int: Int] {
        guard let source else { return [:] }

        var found: [Int: Int] = [:]

        for number in source.changes.removed.keys {
            var line = number
            while source.changes.kinds[line] != nil {
                found[line] = number
                line -= 1
            }

            line = number + 1
            while source.changes.kinds[line] != nil {
                found[line] = number
                line += 1
            }

            found[number] = number
        }

        return found
    }

    func drawFoldRibbon(for line: Int, top: CGFloat, height: CGFloat, source: Source) {
        let fold = source.folds.fold(startingAt: line) ?? source.folds.owner(of: line)
        guard let fold else { return }

        let x = foldColumn(source) + (Metric.chevron - Metric.ribbon) / 2
        let rect = NSRect(x: x, y: top, width: Metric.ribbon, height: height)

        if source.folded.contains(fold.header) {
            NSColor.controlAccentColor.withAlphaComponent(0.9).setFill()
        } else if hovered == fold.header {
            NSColor.white.withAlphaComponent(0.55).setFill()
        } else {
            NSColor.white.withAlphaComponent(0.14).setFill()
        }

        NSBezierPath(
            roundedRect: rect.insetBy(dx: 0, dy: line == fold.header || line == fold.end ? 1 : 0),
            xRadius: Metric.ribbon / 2,
            yRadius: Metric.ribbon / 2
        ).fill()
    }

    func drawRemovedRibbon(top: CGFloat, height: CGFloat) {
        let box = NSRect(
            x: ruleThickness - Metric.ribbon - Metric.ribbonGap,
            y: top,
            width: Metric.ribbon,
            height: height
        )

        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(
            roundedRect: box,
            xRadius: Metric.ribbon / 2,
            yRadius: Metric.ribbon / 2
        ).fill()
    }

    func drawChangeRibbon(for line: Int, top: CGFloat, height: CGFloat, source: Source) {
        guard let change = source.changes.kinds[line + 1] else { return }

        let expanded = source.expanded.contains(line + 1)
        let box = NSRect(
            x: ruleThickness - Metric.ribbon - Metric.ribbonGap,
            y: top,
            width: Metric.ribbon,
            height: change == .removed ? 3 : height
        )

        // Почему: по яркости полосы видно, есть ли под ней удалённые строки
        let hasRemoval = removalAnchor(for: line, source: source) != nil

        if expanded {
            NSColor.systemRed.withAlphaComponent(0.9).setFill()
        } else {
            NSColor.controlAccentColor.withAlphaComponent(hasRemoval ? 0.95 : 0.4).setFill()
        }

        NSBezierPath(
            roundedRect: box,
            xRadius: Metric.ribbon / 2,
            yRadius: Metric.ribbon / 2
        ).fill()
    }

    func line(at y: CGFloat) -> Int? {
        guard let text = clientView as? NSTextView else { return nil }

        var found: Int?

        enumerateVisibleFragments(from: y, in: text) { line, top, height, _ in
            guard top <= y, top + height > y else { return top <= y }

            found = line
            return false
        }

        return found
    }

    func enumerateVisibleFragments(
        from y: CGFloat,
        in text: NSTextView,
        body: (Int?, CGFloat, CGFloat, Bool) -> Bool
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

            return body(sourceLine(of: fragment), top, frame.height, isGap(fragment))
        }
    }
}
