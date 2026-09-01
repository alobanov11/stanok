import AppKit

final class PassingScrollView: NSScrollView {

    override func scrollWheel(with event: NSEvent) {
        // Почему: карточка ревью не скроллится сама, вертикаль принадлежит общему списку
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else {
            nextResponder?.scrollWheel(with: event)
            return
        }

        super.scrollWheel(with: event)
    }
}
