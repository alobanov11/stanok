import Foundation
import StanokKit

@MainActor
@Observable
final class TerminalScrollController {

    static let idleDelay = Duration.seconds(1.2)

    private(set) var scrollbar: TerminalScrollbar?
    private(set) var isShown = false

    @ObservationIgnored
    var scroll: ((Int) -> Void)?

    @ObservationIgnored
    private var hiding: Task<Void, Never>?

    func scroll(rows: Int) {
        scroll?(rows)
    }

    func report(_ scrollbar: TerminalScrollbar) {
        guard self.scrollbar != scrollbar else { return }

        self.scrollbar = scrollbar
        show()
    }

    func show() {
        if !isShown, scrollbar?.isScrollable == true { isShown = true }

        hiding?.cancel()
        hiding = Task { [weak self] in
            try? await Task.sleep(for: Self.idleDelay)
            guard !Task.isCancelled else { return }

            self?.hide()
        }
    }

    func hide() {
        guard isShown else { return }

        isShown = false
    }
}
