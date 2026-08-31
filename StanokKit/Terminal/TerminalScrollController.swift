import Foundation

@MainActor
final class TerminalScrollController {

    var scroll: ((Int) -> Void)?

    func scroll(rows: Int) {
        scroll?(rows)
    }
}
