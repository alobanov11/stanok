import SwiftUI

struct PaneDropDelegate: DropDelegate {

    let target: TerminalSession.ID

    @Binding
    var dragged: TerminalSession.ID?

    @Binding
    var highlighted: TerminalSession.ID?

    let swap: (TerminalSession.ID, TerminalSession.ID) -> Void

    // Почему: чужой текстовый drop не должен тасовать терминалы, тянуть можно только свои
    func validateDrop(info: DropInfo) -> Bool {
        guard let dragged, dragged != target else { return false }

        return true
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }

        highlighted = target
    }

    func dropExited(info: DropInfo) {
        guard highlighted == target else { return }

        highlighted = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        validateDrop(info: info) ? DropProposal(operation: .move) : DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dragged = nil
            highlighted = nil
        }

        guard let dragged, dragged != target else { return false }

        swap(dragged, target)

        return true
    }
}
