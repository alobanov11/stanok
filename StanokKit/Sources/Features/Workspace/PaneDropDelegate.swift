import SwiftUI

struct PaneDropDelegate: DropDelegate {

    let target: TerminalSession.ID

    @Binding
    var dragged: TerminalSession.ID?

    @Binding
    var highlighted: TerminalSession.ID?

    let swap: (TerminalSession.ID, TerminalSession.ID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let dragged else { return false }

        return dragged != target
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }

        highlighted = target
    }

    func dropExited(info: DropInfo) {
        guard highlighted == target else { return }

        highlighted = nil
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
