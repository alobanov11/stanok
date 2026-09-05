import AppKit

final class PlainCopyTextView: NSTextView {

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.string]
    }

    var onCommandClick: ((NSPoint) -> Void)?

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command), let onCommandClick else {
            super.mouseDown(with: event)
            return
        }

        onCommandClick(convert(event.locationInWindow, from: nil))
    }

    override func writeSelection(
        to pasteboard: NSPasteboard,
        types: [NSPasteboard.PasteboardType]
    ) -> Bool {
        let selected = selectedRange()
        guard selected.length > 0, let storage = textStorage else { return false }

        pasteboard.declareTypes([.string], owner: nil)
        return pasteboard.setString(storage.attributedSubstring(from: selected).string, forType: .string)
    }
}
