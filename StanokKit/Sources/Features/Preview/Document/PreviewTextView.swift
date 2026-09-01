import AppKit
import SwiftUI

struct PreviewTextView: NSViewRepresentable {

    enum Mode {

        case reading
        case code
    }

    final class Coordinator: NSObject, NSTextViewDelegate {

        var openLink: ((URL) -> Void)?
        var revision: String?

        private var observer: NSObjectProtocol?

        deinit {
            guard let observer else { return }

            NotificationCenter.default.removeObserver(observer)
        }

        func observe(_ scroll: NSScrollView) {
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scroll.contentView,
                queue: .main
            ) { [weak scroll] _ in
                scroll?.verticalRulerView?.needsDisplay = true
            }
        }

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
    let topInset: CGFloat
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
        text.delegate = context.coordinator
        text.isVerticallyResizable = true
        text.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .cursor: NSCursor.pointingHand
        ]

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false
        scroll.hasVerticalScroller = true
        scroll.documentView = text
        scroll.autohidesScrollers = true

        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.observe(scroll)
        configure(scroll, text: text)

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.openLink = openLink

        guard let text = scroll.documentView as? NSTextView else { return }

        configure(scroll, text: text)

        guard context.coordinator.revision != document.revision else { return }

        context.coordinator.revision = document.revision
        text.textStorage?.setAttributedString(document.text)
        scroll.tile()
        scroll.verticalRulerView?.needsDisplay = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    private func configure(_ scroll: NSScrollView, text: NSTextView) {
        text.textContainerInset = NSSize(width: mode == .code ? 0 : 18, height: 14)
        scroll.contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        scroll.scrollerInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)

        switch mode {
        case .reading:
            text.isHorizontallyResizable = false
            text.autoresizingMask = [.width]
            text.textContainer?.widthTracksTextView = true
            scroll.hasHorizontalScroller = false

        case .code:
            text.isHorizontallyResizable = true
            text.autoresizingMask = []
            text.textContainer?.widthTracksTextView = false
            text.textContainer?.size = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            scroll.hasHorizontalScroller = true
        }

        applyRuler(scroll, text: text)
    }

    private func applyRuler(_ scroll: NSScrollView, text: NSTextView) {
        guard let gutter else {
            scroll.rulersVisible = false
            scroll.verticalRulerView = nil
            scroll.hasVerticalRuler = false
            return
        }

        scroll.hasVerticalRuler = true

        if let ruler = scroll.verticalRulerView as? CodeGutterRuler {
            ruler.source = gutter
            ruler.needsDisplay = true
            return
        }

        let ruler = CodeGutterRuler(scrollView: scroll, orientation: .verticalRuler)
        ruler.reservedThicknessForMarkers = 0
        ruler.reservedThicknessForAccessoryView = 0
        ruler.clientView = text
        ruler.source = gutter
        scroll.verticalRulerView = ruler
        scroll.rulersVisible = true
    }
}
