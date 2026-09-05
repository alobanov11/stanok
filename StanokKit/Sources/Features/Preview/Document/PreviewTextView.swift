import AppKit
import SwiftUI

struct PreviewTextView: NSViewRepresentable {

    enum Mode {

        case reading
        case code
    }

    // Почему: уведомление о скролле приходит вне актора, а координатор не Sendable
    final class ScrollSignal: @unchecked Sendable {

        var action: (@MainActor () -> Void)?
    }

    final class Coordinator: NSObject, NSTextViewDelegate {

        var openLink: ((URL) -> Void)?
        var noteLine: Int?

        let scrollSignal = ScrollSignal()

        var revision: String?
        var shape: String?
        var fileKey: String?
        var measuredKey: String?
        var measured: CGFloat?

        private var observer: NSObjectProtocol?

        deinit {
            guard let observer else { return }

            NotificationCenter.default.removeObserver(observer)
        }

        @MainActor
        func observe(_ scroll: NSScrollView) {
            let signal = scrollSignal

            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scroll.contentView,
                queue: .main
            ) { [weak scroll] _ in
                MainActor.assumeIsolated {
                    scroll?.verticalRulerView?.needsDisplay = true
                    signal.action?()
                }
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

    static let noteHeight: CGFloat = 34

    let document: PreviewDocument
    let fileKey: String
    let shape: String
    let mode: Mode
    let gutter: CodeGutterRuler.Source?
    let topInset: CGFloat
    let openLink: (URL) -> Void

    var scrolls = true
    var contentLines: Int?
    var noteLine: Int?
    var onNoteFrame: ((CGRect) -> Void)?
    var onScroll: (@MainActor () -> Void)?

    static func placeholder() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = noteHeight
        style.maximumLineHeight = noteHeight

        // Почему: без метки просвета гаттер рисует на этой строке полосу удаления
        return NSAttributedString(
            string: "\n",
            attributes: [.paragraphStyle: style, PreviewDocument.gap: true]
        )
    }

    static func crossfade(_ text: NSTextView, scroll: NSScrollView) {
        for view in [text, scroll.verticalRulerView].compactMap(\.self) {
            view.wantsLayer = true

            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.16
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer?.add(fade, forKey: "contents")
        }
    }

    // Почему: высота строки берётся из метрик шрифта, чтобы не будить раскладку при измерении
    static func lineHeight(of scroll: NSScrollView) -> CGFloat? {
        guard let text = scroll.documentView as? NSTextView, let font = text.font else { return nil }

        let height = NSLayoutManager().defaultLineHeight(for: font)

        return height > 0 ? height : nil
    }

    static func height(of scroll: NSScrollView, width: CGFloat, mode: Mode) -> CGFloat {
        guard
            let text = scroll.documentView as? NSTextView,
            let layout = text.textLayoutManager
        else { return 0 }

        // Почему: в режиме чтения перенос зависит от ширины, мерить надо по предложенной
        if mode == .reading, width > 0 {
            text.setFrameSize(NSSize(width: width, height: text.frame.height))
            text.textContainer?.size = NSSize(
                width: width - text.textContainerInset.width * 2,
                height: .greatestFiniteMagnitude
            )
        }

        layout.ensureLayout(for: layout.documentRange)

        return layout.usageBoundsForTextContainer.height + text.textContainerInset.height * 2
    }

    static func anchor(for line: Int, in storage: NSTextStorage) -> Int? {
        var found: Int?

        storage.enumerateAttribute(
            PreviewDocument.sourceLine,
            in: NSRange(location: 0, length: storage.length)
        ) { value, range, stop in
            guard value as? Int == line - 1 else { return }

            found = NSMaxRange(range)
            stop.pointee = true
        }

        guard let found else { return nil }

        return min(found, storage.length)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let text = PlainCopyTextView(usingTextLayoutManager: true)
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.usesFindBar = scrolls
        text.isIncrementalSearchingEnabled = scrolls
        text.delegate = context.coordinator
        text.isVerticallyResizable = true
        text.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .cursor: NSCursor.pointingHand
        ]

        let scroll = scrolls ? NSScrollView() : PassingScrollView()
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false
        scroll.hasVerticalScroller = scrolls
        scroll.documentView = text
        scroll.autohidesScrollers = true
        // Почему: обычный скроллер занимает ширину и при анимации панели дёргает текст
        scroll.scrollerStyle = .overlay

        if !scrolls {
            scroll.verticalScrollElasticity = .none
            scroll.horizontalScrollElasticity = .none
        }

        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.observe(scroll)

        configure(scroll, text: text)

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.openLink = openLink
        context.coordinator.scrollSignal.action = onScroll

        guard let text = scroll.documentView as? NSTextView else { return }

        configure(scroll, text: text)

        let opened = context.coordinator.fileKey != fileKey
        context.coordinator.fileKey = fileKey

        if context.coordinator.revision != document.revision {
            let folding = context.coordinator.shape != nil
                && context.coordinator.shape != shape
                && !opened
            context.coordinator.revision = document.revision
            context.coordinator.shape = shape

            // Почему: TextKit меняет текст мгновенно, кроссфейд прячет рывок при сворачивании
            if folding { Self.crossfade(text, scroll: scroll) }

            text.textStorage?.setAttributedString(document.text)
            context.coordinator.noteLine = nil
            scroll.tile()
            scroll.verticalRulerView?.needsDisplay = true
        }

        applyNote(scroll, text: text, context: context)

        guard opened else { return }

        text.setSelectedRange(NSRange(location: 0, length: 0))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: -scroll.contentInsets.top))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    // Почему: под строкой освобождается настоящая строка документа, поле не ложится поверх кода
    func applyNote(_ scroll: NSScrollView, text: NSTextView, context: Context) {
        guard context.coordinator.noteLine != noteLine else { return }

        let storage = text.textStorage
        context.coordinator.noteLine = noteLine
        storage?.setAttributedString(document.text)

        guard let noteLine, let storage, let layout = text.textLayoutManager else {
            scroll.verticalRulerView?.needsDisplay = true

            return
        }

        guard let anchor = Self.anchor(for: noteLine, in: storage) else { return }

        storage.insert(Self.placeholder(), at: anchor)
        layout.ensureLayout(for: layout.documentRange)
        scroll.verticalRulerView?.needsDisplay = true

        guard
            let location = layout.location(layout.documentRange.location, offsetBy: anchor + 1),
            let fragment = layout.textLayoutFragment(for: location)
        else { return }

        let frame = fragment.layoutFragmentFrame.offsetBy(
            dx: text.textContainerOrigin.x,
            dy: text.textContainerOrigin.y
        )

        onNoteFrame?(text.convert(frame, to: scroll))
    }

    func fixedHeight(of nsView: NSScrollView) -> CGFloat? {
        guard let contentLines, contentLines > 0, let line = Self.lineHeight(of: nsView)
        else { return nil }

        let inset = (nsView.documentView as? NSTextView)?.textContainerInset.height ?? 0

        return CGFloat(contentLines) * line + inset * 2
    }

    func measuredHeight(of nsView: NSScrollView, width: CGFloat, context: Context) -> CGFloat {
        let key = document.revision + "@\(Int(width))"

        if context.coordinator.measuredKey == key, let measured = context.coordinator.measured {
            return measured
        }

        let height = Self.height(of: nsView, width: width, mode: mode)
        context.coordinator.measuredKey = key
        context.coordinator.measured = height

        return height
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSScrollView,
        context: Context
    ) -> CGSize? {
        let proposed = proposal.width ?? nsView.frame.width
        let width = proposed.isFinite ? proposed : nsView.frame.width
        guard !scrolls else { return CGSize(width: width, height: proposal.height ?? 0) }

        if let fixed = fixedHeight(of: nsView) {
            return CGSize(width: width, height: fixed)
        }

        return CGSize(
            width: width,
            height: measuredHeight(of: nsView, width: width, context: context)
        )
    }

    private func configure(_ scroll: NSScrollView, text: NSTextView) {
        let inset = NSSize(width: mode == .code ? 10 : 18, height: 14)

        // Почему: перезапись тех же вставок на каждом кадре анимации перекладывает весь текст
        if text.textContainerInset != inset { text.textContainerInset = inset }

        if scroll.contentInsets.top != topInset {
            scroll.contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
            scroll.scrollerInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        }

        if scroll.scrollerStyle != .overlay { scroll.scrollerStyle = .overlay }

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
            scroll.hasHorizontalScroller = scrolls
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
            let before = ruler.stamp
            ruler.source = gutter

            // Почему: лишняя перерисовка гаттера обходит фрагменты текста на каждом кадре
            if ruler.stamp != before { ruler.needsDisplay = true }

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
