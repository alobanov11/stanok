import AppKit
import SwiftUI

struct PreviewTextView: NSViewRepresentable {

    enum Mode {

        case reading
        case code
    }

    final class Coordinator: NSObject, NSTextViewDelegate {

        var openLink: ((URL) -> Void)?

        func textView(_ view: NSTextView, clickedOnLink link: Any, at index: Int) -> Bool {
            guard let url = link as? URL ?? (link as? String).flatMap(URL.init(string:)) else {
                return false
            }

            openLink?(url)
            return true
        }
    }

    let document: PreviewDocument
    let mode: Mode
    let gutter: CodeGutterRuler.Source?
    let openLink: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let text = PlainCopyTextView(usingTextLayoutManager: true)
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.usesFindBar = true
        text.isIncrementalSearchingEnabled = true
        text.textContainerInset = NSSize(width: mode == .code ? 0 : 18, height: 14)
        text.delegate = context.coordinator
        text.isVerticallyResizable = true
        text.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .cursor: NSCursor.pointingHand
        ]

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = text
        scroll.autohidesScrollers = true

        switch mode {
        case .reading:
            text.isHorizontallyResizable = false
            text.autoresizingMask = [.width]
            text.textContainer?.widthTracksTextView = true

        case .code:
            text.isHorizontallyResizable = true
            text.textContainer?.widthTracksTextView = false
            text.textContainer?.size = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            scroll.hasHorizontalScroller = true
        }

        if let gutter {
            let ruler = CodeGutterRuler(scrollView: scroll, orientation: .verticalRuler)
            ruler.clientView = text
            ruler.source = gutter
            scroll.verticalRulerView = ruler
            scroll.hasVerticalRuler = true
            scroll.rulersVisible = true
        }

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.openLink = openLink

        guard let text = scroll.documentView as? NSTextView else { return }
        guard text.textStorage?.isEqual(to: document.text) != true else { return }

        text.textStorage?.setAttributedString(document.text)

        guard let ruler = scroll.verticalRulerView as? CodeGutterRuler else { return }

        ruler.source = gutter
        ruler.needsDisplay = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}
